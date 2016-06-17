package hoster;
import data.FileData;
import haxe.io.Eof;
import haxe.Json;
import sys.io.Process;

/**
 * A stub, because Weiyun only works on cs target
 * @author Christoph Otter
 */
class WeiyunStub implements Hoster
{

	public function new()
	{
	}
	
	public function getFiles () : Map<String, FileData> {
		printLines (callWeiyun ());
		
		return null;
	}
	
	public function streamFile (srvPath : String) : Void
		printLines (callWeiyun ());
	
	public function downloadFile (srvPath : String, dstFile : String, bufferSize : Int = 48000000) : Void
		printLines (callWeiyun ());
	
	public function uploadFile (file : String, dstPath : String) : Void
		printLines (callWeiyun ());
	
	public function renameFile (file : String, newFile : String) : Void
		printLines (callWeiyun ());
	
	public function deleteFile (file : String) : Void
		printLines (callWeiyun ());
	
	public function setup () : Void
		printLines (callWeiyun ());
	
	inline function callWeiyun () : Array<String>
	{
		var p = new Process ("weiyun.exe", Sys.args ());
		p.exitCode ();
		
		var data = [];
		try {
			data.push (p.stdout.readLine ());
		} catch( e : Eof ) {
		}
		try {
			data.push (p.stderr.readLine ());
		} catch( e : Eof ) {
		}
		
		return data;
	}
	
	inline function printLines (lines : Array<String>) : Void
	{
		for (line in lines)
			Sys.println (line);
	}
	
}
