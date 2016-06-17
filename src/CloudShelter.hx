package;
import data.FileData;
import haxe.io.Path;
import haxe.Json;
import hoster.Hoster;
import sys.FileSystem;
import sys.io.File;
import util.FileIO;


/**
 * ...
 * @author Christoph Otter
 */
class CloudShelter
{
	static var crypto : Crypto;
	static var services : Map<String, Hoster>;
	
	static function main () : Void
	{
		#if cs
		MainHook; //to keep it
		#end
		
		var args = Sys.args ().copy ();
		
		//TODO: multi threading
		//TODO: GPU based encryption / decryption
		
		if (args.length == 0) {
			Sys.println ("Usage:");
			
			Sys.println ("cloudshelter encrypt FILE PASSWORD");
			Sys.println ("\tEncrypts FILE (if FILE is a folder, the foldername and all its files are encrypted)");
			
			Sys.println ("cloudshelter decrypt FILE PASSWORD");
			Sys.println ("\tDecrypts FILE");
			
			Sys.println ("cloudshelter upload SRCFILE DSTPATH SERVICE PASSWORD");
			Sys.println ("\tEncrypts and uploads SRCFILE to DSTPATH on SERVICE");
			
			Sys.println ("cloudshelter download SRVPATH DSTFILE SERVICE PASSWORD");
			Sys.println ("\tDownloads and decrypts SRVPATH from SERVICE to DSTFILE");
			
			Sys.println ("cloudshelter stream SRVPATH SERVICE PASSWORD");
			Sys.println ("\tStreams SRVPATH from SERVICE and opens it with the default program (make sure it supports streaming)");
			
			Sys.println ("cloudshelter rename OLDPATH NEWPATH SERVICE PASSWORD");
			Sys.println ("\tMoves OLDPATH hosted on SERVICE and moves it to NEWPATH");
			
			Sys.println ("cloudshelter delete PATH SERVICE PASSWORD");
			Sys.println ("\tDeletes PATH hosted on SERVICE");
			
			Sys.println ("cloudshelter files SERVICE PASSWORD");
			Sys.println ("\tPrints all files on SERVICE in json format");
			
			Sys.println ("cloudshelter setup SERVICE");
			Sys.println ("\tSets up SERVICE for future usage (getting access permission, etc...)");
			
			Sys.println ("");
			Sys.println ("List of supported SERVICES: ");
			#if cs
			Sys.println ("\tWeiyun");
			#else
			Sys.println ("\tGDrive");
			Sys.println ("\tDropbox");
			#end
			
			Sys.println ("");
			
			return;
		}
		
		var password = args.pop ();
		
		switch (args[0]) {
			case "encrypt":
				checkArgs (3);
				
				var srcFile = Path.normalize (args[1]);
				
				var to = encrypt (srcFile, password);
				
				Sys.println ("Encrypted to:");
				Sys.println (to);
			case "decrypt":
				checkArgs (3);
				
				var srcFile = Path.normalize (args[1]);
				
				var to = decrypt (srcFile, password);
				
				Sys.println ("Decrypted to:");
				Sys.println (to);
				
			case "upload":
				checkArgs (5);
				
				var srcFile = args[1];
				var dstPath = args[2];
				var service = args[3];
				
				upload (srcFile, dstPath, service, password);
			case "download":
				checkArgs (5);
				
				var srvPath = args[1];
				var dstFile = args[2];
				var service = args[3];
				
				download (srvPath, dstFile, service, password);
			case "stream":
				checkArgs (4);
				
				var srvPath = args[1];
				var service = args[2];
				
				stream (srvPath, service, password);
			case "rename":
				checkArgs (5);
				
				var old = args[1];
				var ren = args[2];
				var service = args[3];
				
				rename (old, ren, service, password);
			case "files":
				checkArgs (3);
				
				var service = args[1];
				
				var f = files (service, password);
				
				Sys.println (f);
			case "delete":
				checkArgs (4);
				
				var path = args[1];
				var service = args[2];
				
				delete (path, service, password);
				
			case "setup":
				checkArgs (2);
				
				var service = password;
				setup (service);
		}
	}
	
	public static function encrypt (file : String, password : String) : String
	{
		init (password, false);
		
		if (FileSystem.isDirectory (file)) {
			var dstFolder = Path.join ([Path.directory (file), crypto.encryptFilename (Path.withoutDirectory (file))]);
			
			loopFolder (file, function (f : String) {
				//FIXME: no slashes?
				var relative = StringTools.replace (f, Path.addTrailingSlash (Path.directory (file)), "");
				var dstFile = Path.join ([dstFolder, crypto.encryptFilename (relative)]);
				
				if (!FileSystem.exists (dstFolder))
					FileIO.createFolder (dstFolder);
				
				var to = crypto.encryptToFile (f, dstFile);
			});
			
			return dstFolder;
		}
		else {
			return crypto.encryptToFile (file);
		}
	}
	
	public static function decrypt (file : String, password : String) : String
	{
		init (password, false);
		
		if (FileSystem.isDirectory (file)) {
			var dstFolder = Path.directory (file);
			
			loopFolder (file, function (f : String) {
				var dstFile = Path.join ([dstFolder, crypto.decryptFilename (Path.withoutDirectory (f))]);
				
				if (!FileSystem.exists (dstFolder))
					FileIO.createFolder (dstFolder);
				
				var to = crypto.decryptToFile (f, dstFile);
			});
			
			return dstFolder;
		}
		else {
			return crypto.decryptToFile (file);
		}
	}
	
	public static function upload (srcFile : String, dstFile : String, service : String, password : String) : Void
	{
		init (password);
		
		var file = crypto.encryptToFile (srcFile);
		
		var provider = services.get (service);
		if (provider == null) throw "Error: Provider not supported";
		provider.uploadFile (file, dstFile);
		
		FileSystem.deleteFile (file);
	}
	
	public static function download (srvPath : String, dstFile : String, service : String, password : String) : Void
	{
		init (password);
		
		var encryptedFile = crypto.encryptFilename (dstFile);
		
		var provider = services.get (service);
		if (provider == null) throw "Error: Provider not supported";
		provider.downloadFile (srvPath, encryptedFile);
		
		FileIO.createFolder (Path.directory (dstFile));
		var file = crypto.decryptToFile (encryptedFile);
		FileSystem.deleteFile (encryptedFile);
	}
	
	public static function stream (path : String, service : String, password : String) : Void
	{
		init (password);
		
		var provider = services.get (service);
		if (provider == null) throw "Error: Provider not supported";
		provider.streamFile (path);
	}
	
	public static function rename (oldPath : String, newPath : String, service : String, password : String) : Void
	{
		init (password);
		
		var provider = services.get (service);
		if (provider == null) throw "Error: Provider not supported";
		provider.renameFile (oldPath, newPath);
	}
	
	public static function delete (path : String, service : String, password : String) : Void
	{
		init (password);
		
		var provider = services.get (service);
		if (provider == null) throw "Error: Provider not supported";
		provider.deleteFile (path);
	}
	
	public static function files (service : String, password : String) : String
	{
		init (password);
		
		var provider = services.get (service);
		if (provider == null) throw "Error: Provider not supported";
		var files : Map<String, FileData> =	provider.getFiles ();
		
		var json = { };
		
		if (files == null)
			return Json.stringify (json);
		
		for (key in files.keys ()) {
			var file = files.get (key);
			var f = { };
			
			for (field in Reflect.fields (file))
				Reflect.setField (f, field, Reflect.field (file, field));
			
			Reflect.setField (json, key, f);
		}
		
		return Json.stringify (json);
	}
	
	public static function setup (service : String) : Void
	{
		init ("");
		
		var provider = services.get (service);
		if (provider == null) throw "Error: Provider not supported";
		provider.setup ();
	}
	
	inline static function init (password : String, initServices = true) : Void
	{
		crypto = new Crypto (password);
		
		if (initServices) {
			services = [
				#if cs
				"Weiyun" => new hoster.Weiyun (crypto),
				#else
				"GDrive" => new hoster.GDrive (crypto),
				"Dropbox" => new hoster.Dropbox (crypto),
				"Weiyun" => new hoster.WeiyunStub ()
				#end
			];
		}
	}
	
	inline static function checkArgs (numArgs : Int) {
		if (Sys.args ().length != numArgs)
			throw "Error: Wrong number of arguments";
	}
	
	static function loopFolder (folder : String, onFile : String -> Void) : Void
	{
		for (f in FileSystem.readDirectory (folder)) {
			var file = Path.join ([folder, f]);
			trace (file);
			
			if (FileSystem.isDirectory (file))
				loopFolder (file, onFile);
			else
				onFile (file);
		}
	}
	
}
