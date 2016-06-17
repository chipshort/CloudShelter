package hoster;
import data.FileData;
import haxe.crypto.BaseCode;
import haxe.crypto.Md5;
import haxe.crypto.Sha1;
import haxe.Http;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import hoster.weiyun.FrmLogin;
import sys.FileSystem;
import sys.io.File;
import util.FileIO;
import util.System;

/**
 * Reverse engineered Hoster implementation for weiyun.com
 * Based on: http://blog.macuyiko.com/post/2014/this-is-what-the-chinese-cloud-looks-like.html
 * Only works on cs target, and even there it does not work flawlessly
 * Uploading is not supported
 * @author Christoph Otter
 */
class Weiyun implements Hoster
{
	var crypto : Crypto;
	var appFolderKey : String;
	
	var requestHeader = {
		cmd: 0,
		appid: 30013,
		version: 2,
		major_version: 2
	}
	
	public function new (c : Crypto)
	{
		//max folder name length: 225
		//max file name length: 255
		
		crypto = c;
		
		#if !dll
		cs.system.windows.forms.Application.EnableVisualStyles ();
		cs.system.windows.forms.Application.SetCompatibleTextRenderingDefault (false);
		#end
	}
	
	public function setup () : Void
	{
		if (!Lambda.empty (FrmLogin.cookies)) return;
		
		if (FileSystem.exists ("weiyun_cookies")) {
			var cookies = Unserializer.run (File.getContent ("weiyun_cookies"));
			FrmLogin.cookies = cookies;
			
			try {
				getMainFolder ();
			}
			catch (e : Dynamic) {
				login ();
			}
		}
		else {
			login ();
		}
	}
	
	public function getFiles () : Map<String, FileData>
	{
		setup ();
		
		if (appFolderKey == null) getMainFolder ();
		
		var files = internalGetFiles (appFolderKey, "CloudShelter").files;
		
		var folderStructure = new Map<String, FileData> ();
		
		for (file in files) {
			var f = FileData.fromWFile (file);
			folderStructure.set (crypto.decryptFilename (f.path), f);
		}
		
		/*files.sort (function (a : WFile, b : WFile) {
			var nameA = FileData.getNameOfWFile (a);
			var nameB = FileData.getNameOfWFile (b);
			
			if (nameA < nameB) return -1;
			if (nameA > nameB) return 1;
			
			
			var numA = FileData.getNumOfWFile (a);
			var numB = FileData.getNumOfWFile (b);
			
			if (numA < numB) return -1;
            if (numA > numB) return 1;
            return 0; //this is unexpected
		});
		
		var fileBatchName = "";
		var fileBatch = new Array<WFile> ();
		
		for (file in files) {
			var fileName = FileData.getNameOfWFile (file);
			
			if (fileBatchName == "") { //no batch yet
				fileBatchName = fileName;
			}
			else if (fileBatchName != fileName) { //batch ended
				folderStructure.set (crypto.decryptFilename (fileBatchName), FileData.fromWFiles (fileBatch));
				
				//setup fresh batch
				fileBatch = []; //TODO: optimize
				fileBatchName = fileName;
			}
			
			fileBatch.push (file);
		}
		if (fileBatch.length != 0) {
			folderStructure.set (crypto.decryptFilename (fileBatchName), FileData.fromWFiles (fileBatch));
		}*/
		
		return folderStructure;
	}
	
	public function streamFile (srvPath : String) : Void
	{
		setup ();
		
		var files = getFiles ();
		var file = files.get (srvPath);
		
		if (file == null)
			throw "Error: File not found on server";
		
		var bufferSize = 900000;// 56250 * 16 = 0.85mb
		
		var tempFolder = System.getTempFolder ();
		
		var fileName = Path.withoutDirectory (srvPath);
		var dstFile = Path.join ([tempFolder, fileName]);
		
		var out = File.write (dstFile);
		var first = true;
		
		downloadFileData (file, bufferSize, function (bytes : Bytes, last : Bool) {
			var decrypted = crypto.decrypt (bytes, last);
			out.writeBytes (decrypted, 0, decrypted.length);
			
			if (first)
				System.openFile (tempFolder, fileName);
			
			first = false;
		});
		
		out.close ();
	}
	
	public function downloadFile (srvPath : String, dstFile : String, bufferSize : Int = /*48000000*/ 5000000) : Void //using smaller buffer for now
	{
		//TODO: test with large file
		setup ();
		
		var files = getFiles ();
		var f = files.get (srvPath);
		
		if (f == null)
			throw "Error: File not found on server";
		
		var out = File.write (dstFile);
		
		var i = 0;
		downloadFileData (f, bufferSize, function (bytes : Bytes, last : Bool) {
			out.writeBytes (bytes, 0, bytes.length);
			
			var start = i * bufferSize;
			Sys.println (Std.int ((start + bytes.length) / f.fileSize * 100) + "%");
			i++;
		});
		
		out.close ();
		
		Sys.println ("Finished");
	}
	
	public function uploadFile (file : String, dstPath : String) : Void
	{
		throw "Error: Uploading not supported";
		//FIXME: upload does not work
		//maybe make OPTIONS request first? (using ?ver=12345
		
		setup ();
		
		getMainFolder ();
		
		var filename = crypto.encryptFilename (dstPath);
		
		//TODO: delete existing file
		
		//upload file in pieces
		var bufferSize = 130304;//131072; //16 * 8192 //before: 130304
		var partNumber = 0;
		
		var uploadId = "";
		
		FileIO.readFileBuffered (file, bufferSize, function (bytes : Bytes, last : Bool) {
			var md5 = Md5.make (bytes).toHex ();
			var sha = Sha1.make (bytes).toHex ();
			
			var url = getRequestURL ("qdisk_upload.fcg", 2301, {
				"ReqMsg_body": {
					"weiyun.DiskFileUploadMsgReq_body": {
						"ppdir_key": "157f3badf0a739ae12b58dcd423dce4a",
						"pdir_key": appFolderKey,
						"upload_type": 0,
						"file_md5": md5,
						"file_sha": sha,
						"file_size": bytes.length,
						"filename": filename + ";" + partNumber,
						"file_exist_option": 4 //TODO: replace?
					}
				}
			});
			
			trace (url);
			
			var data = request (url);
			trace (data);
			data = Reflect.field (data.rsp_body.RspMsg_body, "weiyun.DiskFileUploadMsgRsp_body");
			trace (data.file_exist); //should always be false?
			trace (data.file_key);
			var host : String = data.server_name;
			/*host = StringTools.replace (host, ".", "-");
			host = StringTools.replace (host, "-qq-com", ".weiyun.com");*/
			trace (host);
			
			var url = "http://" + host + /*":" + data.server_port +*/ "/ftn_handler/?bmd5=" + md5;
			
			trace (url);
			
			var h = new Http (url);
			
			//get cookies
			var cookie = "";
			for (key in FrmLogin.cookies.keys ()) {
				var c = FrmLogin.cookies.get (key);
				cookie += key + "=" + c + "; ";
			}
			cookie = cookie.substr (0, cookie.length - 2);
			trace (cookie);
			
			var postData = encodeFile (data.check_key, data.file_key, filename, bytes);
			trace (postData.length);
			h.setPostData (postData);
			
			h.setHeader ("Cookie", cookie);
			h.setHeader ("Origin", "http://www.weiyun.com");
			//h.setHeader ("Referer", "http://img.weiyun.com/club/qqdisk/web/FileUploader.swf?r=B2F0F0EA_AC24_4C65_A2FA_8D56EB4294CD");
			h.setHeader ("Content-Type", "application/octet-stream");
			h.setHeader ("Conent-Length", Std.string (postData.length));
			//h.fileTransfer ("file", filename + ";" + partNumber, new BytesInput (bytes), bytes.length);
			h.setHeader ("Connection", "keep-alive");
			
			h.onStatus = function (status : Int) {
				trace (status);
			}
			
			h.onError = function (e : String) {
				trace (e);
			}
			
			h.onData = function (data : String) {
				trace (data);
			}
			
			h.customRequest (true, new BytesOutput ());
			trace (h.responseData);
			
			//trace (h.responseHeaders);
			trace ("upload done");
			/*h.setHeader ("Content-Type", "application/octet-stream");
			h.setHeader ("Content-Length", "130307"); //TODO: change this*/
			//h.setPostData (
			
			//Sys.println (Std.int ((sizeTillNow + bytes.length) / fileStat.size * 100) + "%");
			partNumber++;
			trace (getFiles ());
		});
		//finish upload
		/*request ("https://content.dropboxapi.com/1/commit_chunked_upload/auto/" + title, "POST", {
			overwrite: true,
			upload_id: uploadId
		}, DataFormat.PARAMS);*/
		
		Sys.println ("Finished");
	}
	
	public function renameFile (file : String, newFile : String) : Void
	{
		//throw "Error: Renaming not supported";
		setup ();
		
		var files = getFiles ();
		var f = files.get (file);
		
		if (f == null)
			throw "Error: File not found on server";
		
		var url = getRequestURL ("qdisk_modify.fcg", 2606, {
			"ReqMsg_body": {
				"weiyun.DiskFileBatchRenameMsgReq_body": {
					"ppdir_key": "157f3badf0a739ae12b58dcd423dce4a",
					"pdir_key": appFolderKey,
					"file_list": [{
						"file_id": f.id,
						"filename": crypto.encryptFilename (newFile),
						"src_filename": f.path
					}]
				}
			}
		});
		
		request (url);
		
		Sys.println ("Finished");
	}
	
	public function deleteFile (file : String) : Void
	{
		//throw "Error: Renaming not supported";
		setup ();
		
		var files = getFiles ();
		var f = files.get (file);
		
		if (f == null)
			throw "Error: File not found on server";
		
		var url = getRequestURL ("qdisk_delete.fcg", 2505, {
			"ReqMsg_body": {
				"weiyun.DiskDirFileBatchDeleteMsgReq_body": {
					"ppdir_key": "157f3badf0a739ae12b58dcd423dce4a",
					"pdir_key": appFolderKey,
					"file_list": [{
						"file_id": f.id,
						"filename": f.path
					}]
				}
			}
		});
		
		request (url);
		
		//empty recycle bin
		
		var url = getRequestURL ("qdisk_recycle.fcg", 2703, {
			"ReqMsg_body": {
				"weiyun.DiskRecycleClearMsgReq_body": {
				}
			}
		});
		
		request (url);
		
		Sys.println ("Finished");
	}
	
	function downloadFileData (file : FileData, bufferSize : Int, onData : Bytes->Bool->Void) : Void
	{
		var fileSize = file.fileSize;
		
		var url = getRequestURL ("qdisk_download.fcg", 2402, {
			"ReqMsg_body": {
				"weiyun.DiskFileBatchDownloadMsgReq_body": {
					"file_list": [{
						"file_id": file.id, //TODO: different parts?
						"filename": file.path, //+ ";" + FileData.getNumOfWFile (file)
						"pdir_key": appFolderKey
					}]
				}
			}
		});
		
		var response = request (url);
		
		var fileList : Array<Dynamic> = Reflect.field (response.rsp_body.RspMsg_body, "weiyun.DiskFileBatchDownloadMsgRsp_body").file_list;
		var fileData = fileList[0];
		FrmLogin.cookies.set (fileData.cookie_name, fileData.cookie_value);
		
		var fileUrl = fileData.download_url;
		var server = fileData.server_name;
		var realServer = StringTools.replace (server, ".", "-");
		realServer = StringTools.replace (realServer, "-qq-com", ".weiyun.com");
		
		fileUrl = StringTools.replace (fileUrl, server, realServer); //TODO: only replace first occurance? (collision is unlikely)
		
		var start = 0;
		
		while (start < fileSize) {
			var end = start + bufferSize;
			if (end > fileSize) end = fileSize;
			end--;
			
			//var bytes = request (fileUrl).responseData;
			
			var h = new Http (fileUrl);
			//Range: "bytes=" start + "-" + end
			//TODO: Range header? (partial download)
			var cookie = getCookie ();
			h.setHeader ("Range", "bytes=" + start + "-" + end);
			h.setHeader ("Cookie", cookie);
			
			var bytesOutput = new haxe.io.BytesOutput();
			h.customRequest (false, bytesOutput);
			var bytes = bytesOutput.getBytes ();
			
			onData (bytes, end == fileSize - 1);
			start += bufferSize;
		}
	}
	
	function encodeFile (ukey : String, filekey : String, filename : String, bytes : Bytes) : String
	{
		var out = new BytesOutput ();
		out.bigEndian = true;
		//out.writeString ("\xab\xcd\x98\x76");
		out.writeInt32 (0xABCD9876);
		out.writeInt32 (0x000003E8);
		out.writeInt32 (0);
		var hlen = Std.int (2 * 2 + 4 * 3 + ukey.length / 2 + filekey.length / 2 + bytes.length);
		out.writeInt32 (hlen);
		out.writeInt16 (Std.int (ukey.length / 2));
		var b = hexToBytes (ukey);
		out.writeBytes (b, 0, b.length);
		out.writeInt16 (Std.int (filekey.length / 2));
		b = hexToBytes (filekey);
		out.writeBytes (b, 0, b.length);
		out.writeInt32 (bytes.length); //filesize
		out.writeInt32 (0x6E000000);
		out.writeInt32 (bytes.length);
		out.writeBytes (bytes, 0, bytes.length);
		
		out.flush ();
		out.close ();
		var data = out.getBytes ();
		
		FileIO.writeFile ("tmpData.txt", data);
		
		return readANSI ("tmpData.txt"); //File.getContent ("testoutput2.txt"); //data.toString ();
	}
	
	//TODO: change directly for String
	@:functionCode("return System.IO.File.ReadAllText(file, System.Text.Encoding.Default);")
	function readANSI (file : String) : String
	{
		return "";
	}
	
	function hexToBytes (hex : String) : Bytes
	{
		var base = Bytes.ofString ("0123456789abcdef");
        return new BaseCode (base).decodeBytes (Bytes.ofString (hex.toLowerCase ()));
	}
	
	function getMainFolder () : Void
	{
		//TODO: create new folder if it is not found
		//TODO: do not hardcode ids
		var dirs = internalGetFiles ("157f3badf0a739ae12b58dcd423dce4a", "微云").folders;
		
		for (dir in dirs) {
			if (dir.dir_name == "CloudShelter")
				appFolderKey = dir.dir_key;
		}
	}
	
	function internalGetFiles (key : String, name : String) : { files : Array<WFile>, folders : Array<WFolder> }
	{
		var filesLeft = true;
		var files = new Array<WFile> ();
		var folders = new Array<WFolder> ();
		var i = 0;
		
		while (filesLeft) {
			var url = getRequestURL ("qdisk_get.fcg", 2209, {
				"ReqMsg_body": {
					"weiyun.DiskDirBatchListMsgReq_body": {
						"dir_list": [{
							"get_type": 0,
							"start": i,
							"count": 100, //100 is max
							"sort_field": 2,
							"reverse_order": false,
							"dir_key": key,
							"dir_name": name
						}]
					}
				}
			});
			
			var data : Array<Dynamic> = Reflect.field (request (url).rsp_body.RspMsg_body, "weiyun.DiskDirBatchListMsgRsp_body").dir_list; //TODO: make this easier
			
			var fileList : Array<WFile> = data[0].file_list;
			var folderList : Array<WFolder> = data[0].dir_list;
			
			if (fileList == null && folderList == null) {
				filesLeft = false;
			}
			else {
				if (fileList != null)
					files = files.concat (fileList);
				if (folderList != null)
					folders = folders.concat (folderList);
			}
			
			i += 100;
		}
		
		return {
			files: files,
			folders: folders
		}
	}
	
	function login () : Void
	{
		var user = ""; //"christophotter@gmail.com"
		var pass = ""; //"jL9u84E25t4.?"
		if (FileSystem.exists ("weiyun_login")) {
			var data = File.getContent ("weiyun_login").split ("\n");
			user = data[0];
			pass = data[1];
		}
		else {
			signup ();
			login ();
			return;
		}
		
		var frmRequest = new FrmLogin (user, pass);
		if (frmRequest.ShowDialog () == cs.system.windows.forms.DialogResult.OK)
			File.saveContent ("weiyun_cookies", Serializer.run (FrmLogin.cookies)); //save cookies
	}
	
	function signup () : Void
	{
		
		//wait for code
		Sys.println ("Enter mail:");
		var user = Sys.stdin ().readLine ();
		Sys.println ("Enter password:");
		var pass = Sys.stdin ().readLine ();
		
		File.saveContent ("weiyun_login", user + "\n" + pass);
	}
	
	function getRequestURL (endpoint : String, cmd : Int/*String*/, body : Dynamic) : String
	{
		requestHeader.cmd = cmd;
		var data = {
			"req_header": requestHeader,
			"req_body": body
		}
		
		var skey = FrmLogin.cookies.get ("skey");
		var g_tk = get_tk (skey);
		
		return "http://user.weiyun.com/newcgi/" + endpoint + "?cmd=" + cmd + "&g_tk=" + g_tk + "&callback=get&data=" + StringTools.urlEncode (Json.stringify (data));
	}
	
	function get_tk (skey : String, salt = 5381) : Int
	{
		for (i in 0 ... skey.length) {
			var ac : Int = skey.charCodeAt (i);
			salt += (salt << 5) + ac;
		}
		return salt & 0x7fffffff;
	}
	
	function request (url : String, ?headers : Map<String, String>) : Dynamic
	{
		/*var frmRequest = new FrmLogin (url);
		frmRequest.ShowDialog ();*/
		var h = new Http (url);
		
		var cookie = getCookie ();
			
		h.setHeader ("Cookie", cookie);
		
		if (headers != null) {
			for (key in headers.keys ()) {
				h.setHeader (key, headers.get (key));
			}
		}
		
		h.request (false);
		
		var data = h.responseData;
		data = StringTools.replace (data, "try{get(", "");
		data = StringTools.replace (data, ")}catch(e){};", "");
		//trace (h.responseHeaders.exists ("Set-Cookie"));
		return Json.parse (data);//frmRequest.returnData;
	}
	
	function getCookie () : String
	{
		var cookie = "";
		for (key in FrmLogin.cookies.keys ()) {
			var c = FrmLogin.cookies.get (key);
			cookie += key + "=" + c + "; ";
		}
		return cookie.substr (0, cookie.length - 2);
	}
	
}
