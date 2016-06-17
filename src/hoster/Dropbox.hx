package hoster;
import data.FileData;
import haxe.io.Bytes;
import haxe.io.Path;
import hoster.Hoster;
import oauth.BodyRequest.DataFormat;
import oauth.Consumer;
import oauth.OAuth2;
import oauth.Tokens.AccessToken;
import sys.FileSystem;
import sys.io.File;
import util.FileIO;
import util.System;

typedef DFile = {
	path : String,
	?icon : String,
	bytes : Int,
	?contents : Array<DFile>
}

/**
 * ...
 * @author Christoph Otter
 */
class Dropbox extends OAuthHoster implements Hoster
{
	public function new (c : Crypto)
	{
		//filenames only 255 chars in Dropbox
		//file limit 25000
		var key = FileIO.getContent ("dropboxSecretKey.txt").split ("\n");
		
		super (c, "dropbox_token",
			"https://www.dropbox.com/1/oauth2/authorize", "https://api.dropbox.com/1/oauth2/token", null,
			key[0], key[1]);
	}
	
	public function getFiles () : Map<String, FileData>
	{
		setup ();
		
		var folderStructure = new Map<String, FileData> ();
		var folder : DFile = jsonRequest ("https://api.dropboxapi.com/1/metadata/auto?file_limit=25000");
		
		for (file in folder.contents) {
			var path = file.path;
			if (path.charAt (0) == "/")
				path = path.substring (1, path.length);
			
			folderStructure.set (crypto.decryptFilename (path), FileData.fromDFile (file));
		}
		
		return folderStructure;
	}
	
	public function renameFile (file : String, newFile : String) : Void
	{
		setup ();
		
		var files = getFiles ();
		var f = files.get (file);
		
		if (f == null)
			throw "Error: File not found on server";
		
		request ("https://api.dropboxapi.com/1/fileops/move", "POST", {
			root: "auto",
			from_path: f.id,
			to_path: crypto.encryptFilename (newFile)
		}, DataFormat.PARAMS);
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
			
			//Sys.println (Std.int ((start + bytes.length) / file.bytes * 100) + "%");
			
			if (first)
				System.openFile (tempFolder, fileName);
			
			first = false;
		});
		
		out.close ();
	}
	
	public function downloadFile (srvPath : String, dstFile : String, bufferSize = 48000000) : Void
	{
		setup ();
		
		var files = getFiles ();
		var file = files.get (srvPath);
		
		if (file == null)
			throw "Error: File not found on server";
		
		var out = File.write (dstFile);
		
		var i = 0;
		downloadFileData (file, bufferSize, function (bytes : Bytes, last : Bool) {
			out.writeBytes (bytes, 0, bytes.length);
			
			var start = i * bufferSize;
			Sys.println (Std.int ((start + bytes.length) / file.fileSize * 100) + "%");
			i++;
		});
		
		out.close ();
		
		Sys.println ("Finished");
	}
	
	public function uploadFile (file : String, dstPath : String) : Void
	{
		setup ();
		
		//var files = getFiles ();
		
		var title = crypto.encryptFilename (dstPath);
		var fileStat = FileSystem.stat (file);
		
		//upload file in pieces
		var bufferSize = 4000000;
		var bufferNum = 0;
		
		var uploadId = "";
		
		FileIO.readFileBuffered (file, bufferSize, function (bytes : Bytes, last : Bool) {
			var sizeTillNow = bufferNum * bufferSize; //TODO: use Range from answer instead
			//var range = generateRange (sizeTillNow, sizeTillNow + bytes.length - 1, fileStat.size);
			
			if (bufferNum == 0)
				uploadId = jsonRequest ("https://content.dropboxapi.com/1/chunked_upload?offset=0", "PUT", bytes, DataFormat.BYTES).upload_id;
			else
				sendFileData (bytes, sizeTillNow, uploadId);
			
			Sys.println (Std.int ((sizeTillNow + bytes.length) / fileStat.size * 100) + "%");
			bufferNum++;
		});
		//finish upload
		request ("https://content.dropboxapi.com/1/commit_chunked_upload/auto/" + title, "POST", {
			overwrite: true,
			upload_id: uploadId
		}, DataFormat.PARAMS);
		
		Sys.println ("Finished");
	}
	
	public function deleteFile (file : String) : Void
	{
		setup ();
		
		var files = getFiles ();
		var f = files.get (file);
		
		if (f == null)
			throw "Error: File not found on server";
		
		request ("https://api.dropboxapi.com/1/fileops/delete", "POST", {
			root: "auto",
			path: f.id
		}, DataFormat.PARAMS);
		
		Sys.println ("Finished");
	}
	
	override function login () : Void
	{
		try {
			client = OAuth2.connect (new Consumer (apiKey, secretKey));
			
			var token = File.getContent (tokenFile);
			client.accessToken = new AccessToken (token);
			//client = client.refreshAccessToken (tokenUrl);
			
			saveToken ();
		}
		catch (e : Dynamic) {
			signup (); //we failed, ask for permission again
		}
	}
	
	function sendFileData (bytes : Bytes, offset : Int, uploadId : String) : Void
	{
		//TODO: implement resuming
		request ("https://content.dropboxapi.com/1/chunked_upload?offset=" + offset + "&upload_id=" + uploadId, "PUT", bytes, DataFormat.BYTES);
	}
	
	function downloadFileData (file : FileData, bufferSize : Int, onData : Bytes->Bool->Void) : Void
	{
		var fileSize = file.fileSize;
		var start = 0;
		
		while (start < fileSize) {
			var end = start + bufferSize;
			if (end > fileSize) end = fileSize;
			end--;
			
			var bytes = request ("https://content.dropboxapi.com/1/files/auto" + file.id, "GET", null, null, [
				"Range" => generateRange (start, end)
			]).responseData;
			
			onData (bytes, end == fileSize - 1);
			start += bufferSize;
		}
	}
}
