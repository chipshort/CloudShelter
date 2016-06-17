package util;
import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Error;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * ...
 * @author Christoph Otter
 */
class FileIO
{
	macro public static function getGoogleJson (file : String)
	{
		var content = File.getContent (file);
		var json = haxe.Json.parse (content).installed;
		
		return macro $v{ cast json};
	}
	
	macro public static function getContent (file : String)
	{
		var content = File.getContent (file);
		if (StringTools.endsWith (content, "\n"))
		{
			content = content.substr (0, content.length - 1);
		}
		return macro $v{content};
	}
	
	public static function createFolder (folder : String) : Void
	{
		var parent = Path.directory (folder);
		
		if (parent != "" && parent != "/" && !FileSystem.exists (parent)) {
			createFolder (parent);
		}
		
		if (folder != "" && folder != "/")
			FileSystem.createDirectory (folder);
	}
	
	/**
	 * @return The content of (file) as Bytes; Only use this for small files
	 */
	public static inline function readFile (file : String) : Bytes
	{
		var inp = File.read (file);
		var data = inp.readAll ();
		inp.close ();
		
		return data;
	}
	
	/**
	 * Writes (data) into (file)
	 */
	public static inline function writeFile (file : String, data : Bytes) : Void
	{
		var out = File.write (file);
		out.writeBytes (data, 0, data.length);
		out.close ();
	}
	
	/**
	 * Adds (data) at the end of (file)
	 * WARNING: Potentially inefficient if used many times in a row!
	 */
	public static inline function appendFile (file : String, data : Bytes) : Void
	{
		var out = File.append (file);
		out.writeBytes (data, 0, data.length);
		out.close ();
	}
	
	/**
	 * Reads (file) in steps of (bufferSize) bytes and calls (onData) for every portion of data.
	 * The second argument to (onData) specifies whether this is the last portion or not.
	 */
	public static function readFileBuffered (file : String, bufferSize : Int, onData : Bytes->Bool->Void) : Void
	{
		var fileSize = FileSystem.stat (file).size;
		
		var inp = File.read (file);
		var data = Bytes.alloc(bufferSize);
		
		var sizeCounter = 0;
		
		try {
			while (true) { //sizeCounter < fileSize ???
				//data.fill (0, bufferSize, 0);
				var len = inp.readBytes (data, 0, bufferSize);
				if( len == 0 )
					throw Error.Blocked;
				
				sizeCounter += len;
				if (len < bufferSize)
					onData (data.sub (0, len), true)
				else
					onData (data, sizeCounter == fileSize);
			}
		} catch (e : Eof) {
		}
		
		inp.close ();
	}
}
