package hoster;

import data.FileData;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.Json;
import hoster.Hoster;
import oauth.BodyRequest;
import oauth.Client;
import oauth.Consumer;
import oauth.OAuth2;
import oauth.Tokens.RefreshToken;
import sys.FileSystem;
import sys.io.File;
import util.FileIO;
import util.System;

typedef GKey = {
	client_id : String,
    auth_uri : String,
    token_uri : String,
    client_secret : String,
    redirect_uris : Array<String>,
	project_id : String, //irrelevant, but needed for compilation
	auth_provider_x509_cert_url : String //same here
}

typedef GFile = {
	?id : String,
	?iconLink : String,
	title : String,
	?mimeType : String,
	?labels : { trashed : Bool },
	?parents : Array<{ id : String, ?isRoot : Bool }>,
	?properties : Array<GProperty>,
	?fileSize : Null<Int>
}

typedef GProperty = {
	key : String,
	value : String,
	?visibility : String
}

/**
 * ...
 * @author Christoph Otter
 */
class GDrive extends OAuthHoster implements Hoster
{
	var rootFolderID = "";
	var isSetup = false;
	
	public function new (c : Crypto)
	{
		//filenames (nearly?) unlimited
		//file limit 1000
		var key : GKey = FileIO.getGoogleJson ("driveSecretKey.json");
		
		super (c, "gDrive_token",
			"https://accounts.google.com/o/oauth2/auth", "https://accounts.google.com/o/oauth2/token", key.redirect_uris[0],
			key.client_id, key.client_secret, "https://www.googleapis.com/auth/drive.file");
	}
	
	override public function setup () : Void
	{
		super.setup ();
		
		if (!isSetup) {
			isSetup = true;
			
			//call getFiles to get rootFolderID
			getFiles ();
			
			if (rootFolderID == "") {
				rootFolderID = createFolder ("CloudShelter", "root", [{
					"key": "cloudShelter",
					"value": "*", //root folder
					"visibility": "PRIVATE"
				}]).id;
			}
		}
	}
	
	public function getFiles () : Map<String, FileData>
	{
		setup ();
		
		var folderStructure = new Map<String, FileData> ();
		var items : Array<GFile> = jsonRequest ("https://www.googleapis.com/drive/v2/files?spaces=drive&maxResults=1000").items;
		
		for (file in items) {
			if (!file.labels.trashed) {
				for (prop in file.properties) {
					if (prop.key == "cloudShelter") {
						if (prop.value == "*")
							rootFolderID = file.id;
						else
							folderStructure.set (crypto.decryptFilename (file.title), FileData.fromGFile (file));
					}
				}
			}
		}
		
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
		
		var files = getFiles ();
		
		var title = crypto.encryptFilename (dstPath);
		var fileStat = FileSystem.stat (file);
		
		if (files.exists (dstPath))
			request ("https://www.googleapis.com/drive/v2/files/" + files.get (dstPath).id, "DELETE");
		
		var body : GFile = {
			title: title,
			parents: [{
				id: rootFolderID
			}],
			properties: [{
				key: "cloudShelter",
				value: "true",
				visibility: "PRIVATE"
			}]
		};
		
		//get upload url
		var req = request ("https://www.googleapis.com/upload/drive/v2/files?uploadType=resumable", "POST", body, DataFormat.JSON, [
			"X-Upload-Content-Type" => "application/octet-stream",
			"X-Upload-Content-Length" => Std.string (fileStat.size)
		]);
		var location = req.responseHeaders.get ("Location");
		
		//upload file in pieces
		var bufferSize = 3932160; // 16 * 245760; // 256 * 1024 * 15
		var bufferNum = 0;
		
		FileIO.readFileBuffered (file, bufferSize, function (bytes : Bytes, last : Bool) {
			var sizeTillNow = bufferNum * bufferSize; //TODO: use Range from answer instead
			var range = generateRange (sizeTillNow, sizeTillNow + bytes.length - 1, fileStat.size);
			
			sendFileData (location, bytes, range);
			
			Sys.println (Std.int ((sizeTillNow + bytes.length) / fileStat.size * 100) + "%");
			bufferNum++;
		});
		
		Sys.println ("Finished");
	}
	
	public function renameFile (file : String, newFile : String) : Void
	{
		setup ();
		
		var files = getFiles ();
		var f = files.get (file);
		
		if (f == null)
			throw "Error: File not found on server";
		
		var title = crypto.encryptFilename (newFile);
		
		request ("https://www.googleapis.com/drive/v1/files/" + f.id, "PATCH", {
			title: title
		}, DataFormat.JSON);
		
		Sys.println ("Finished");
	}
	
	public function deleteFile (file : String) : Void
	{
		setup ();
		
		var files = getFiles ();
		var f = files.get (file);
		
		if (f == null)
			throw "Error: File not found on server";
		
		request ("https://www.googleapis.com/drive/v2/files/" + f.id, "DELETE");
		
		Sys.println ("Finished");
	}
	
	function downloadFileData (file : FileData, bufferSize : Int, onData : Bytes->Bool->Void) : Void
	{
		var fileSize = file.fileSize;
		var start = 0;
		
		while (start < fileSize) {
			var end = start + bufferSize;
			if (end > fileSize) end = fileSize;
			end--;
			
			var bytes = request ("https://www.googleapis.com/drive/v2/files/" + file.id + "?alt=media", "GET", null, null, [
				"Range" => generateRange (start, end)
			]).responseData;
			
			onData (bytes, end == fileSize - 1);
			start += bufferSize;
		}
	}
	
	function sendFileData (location : String, bytes : Bytes, range : String) : Void
	{
		//TODO: implement resuming
		var upload = request (location, "PUT", bytes, DataFormat.BYTES, [
			"Content-Range" => range,
			"Content-Length" => Std.string (bytes.length),
			"Content-Type" => "application/octet-stream"
		]);
	}
	
	function createFolder (name : String, parentId = "root", ?properties : Array<GProperty>) : GFile
	{
		var data : GFile = {
			title: name,
			parents: [ { id: parentId } ],
			mimeType: "application/vnd.google-apps.folder"
		};
		if (properties != null) data.properties = properties;
		
		return jsonRequest ("https://www.googleapis.com/drive/v2/files", "POST", data, DataFormat.JSON);
	}
}
