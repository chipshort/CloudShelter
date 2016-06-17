package util;
import sys.FileSystem;

/**
 * ...
 * @author Christoph Otter
 */
class System
{
	public static function openUrl (url : String) : Void
	{
		if (Sys.systemName () == "Windows") {
			trace (url);
			Sys.command ("start", ['""', url]);
		}
		else if (Sys.systemName () == "Linux") {
			trace (url);
			Sys.command ("xdg-open", [url]);
		}
		//TODO: implement for Mac
	}
	
	public static function openFile (folder : String, filename : String) : Void
	{
		if (Sys.systemName () == "Windows") {
			var cwd = Sys.getCwd ();
			
			Sys.setCwd (folder);
			Sys.command ("explorer", [filename]);
			
			Sys.setCwd (cwd);
		}
		else if (Sys.systemName () == "Linux") {
			Sys.command ("xdg-open", [haxe.io.Path.join ([folder, filename])]);
		}
		//TODO: Mac
	}
	
	public static function getTempFolder () : String
	{
		var tempFolder = Sys.getEnv ("TEMP");
		if (!FileSystem.exists (tempFolder))
			tempFolder = "/tmp"; //Sys.getEnv ("TMPDIR"); //TODO: test this on Linux
			
		return tempFolder;
	}
}
