package;
import com.fundoware.engine.crypto.aes.FunAES;
import com.fundoware.engine.crypto.hash.FunSHA2_256;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import util.FileIO;

using StringTools;

/**
 * ...
 * @author Christoph Otter
 */
class Crypto
{
	var sha = new FunSHA2_256 ();
	var aes = new FunAES ();
	
	var key : Bytes;

	public function new (pass : String)
	{
		key = generateKey (pass);
		aes.setKey (key);
	}
	
	public function encryptFilename (file : String) : String
	{
		return Base64.encode (encrypt (Bytes.ofString (file))).replace ("/", "-");
	}
	
	public function decryptFilename (file : String) : String
	{
		return decrypt (Base64.decode (file.replace ("-", "/"))).toString ();
	}
	
	/**
	 * Decrypts the contents of (file) step by step and calls (onData) for every portion of data.
	 * The data given to onData is decrypted already.
	 */
	public function decryptBuffered (file : String, onData : Bytes->Void) : Void
	{
		FileIO.readFileBuffered (file, FunAES.kBlockSize, function (data : Bytes, last : Bool) {
			onData (decrypt (data, last));
		});
	}
	
	/**
	 * Encrypts the contents of (file) step by step and calls (onData) for every portion of data.
	 * The data given to onData is encrypted already.
	 */
	public function encryptBuffered (file : String, onData : Bytes->Void) : Void
	{
		FileIO.readFileBuffered (file, FunAES.kBlockSize, function (data : Bytes, last : Bool) {
			onData (encrypt (data, last));
		});
	}
	
	public function encryptToFile (clearFile : String, ?encryptedFile : String) : String
	{
		var dir = Path.directory (clearFile);
		
		if (encryptedFile == null) encryptedFile = Path.join ([dir, encryptFilename (Path.withoutDirectory (clearFile))]);
		
		//var encryptedFile = Path.join ([dir, encryptFilename (Path.withoutDirectory (clearFile))]);
		
		var out = File.write (encryptedFile);
		
		encryptBuffered (clearFile, function (bytes : Bytes) {
			out.writeBytes (bytes, 0, bytes.length);
		});
		
		out.close ();
		
		return encryptedFile;
	}
	
	public function decryptToFile (encryptedFile : String, ?clearFile : String) : String
	{
		var dir = Path.directory (encryptedFile);
		
		if (clearFile == null) clearFile = Path.join ([dir, decryptFilename (Path.withoutDirectory (encryptedFile))]);
		//var clearFile = decryptFilename (encryptedFile);
		
		var dstDir = Path.directory (clearFile);
		if (!FileSystem.exists (dstDir))
			FileIO.createFolder (dstDir);
		
		var out = File.write (clearFile);
		
		decryptBuffered (encryptedFile, function (bytes : Bytes) {
			out.writeBytes (bytes, 0, bytes.length);
		});
		
		out.close ();
		
		return clearFile;
	}
	
	inline function generateKey (key : String) : Bytes
	{
		var phrase = Bytes.ofString (key);
		var key = Bytes.alloc (FunSHA2_256.kDigestSize);
		
		sha.addBytes (phrase, 0, phrase.length);
		sha.finish (key, 0);
		
		sha.clear ();
		
		return key;
	}
	
	public function encrypt (data : Bytes, padding = true) : Bytes
	{
		var len = FunAES.kBlockSize * Math.ceil (data.length / FunAES.kBlockSize); //we need x * 16
		if (padding && data.length % FunAES.kBlockSize == 0) len += FunAES.kBlockSize; //we also need to pad fitting sizes
		
		var enc = Bytes.alloc (len);
		var d = Bytes.alloc (len); //copy of data in bigger
		d.blit (0, data, 0, data.length);
		
		if (padding) d.set (len - 1, len - data.length); //padding
		
		var i = 0;
		while (i < len) {
			aes.encrypt (d, i, enc, i);
			i += FunAES.kBlockSize;
		}
		
		return enc;
	}
	
	public function decrypt (data : Bytes, padding = true) : Bytes
	{
		var dec = Bytes.alloc (data.length);
		
		var i = 0;
		while (i < data.length) {
			aes.decrypt (data, i, dec, i);
			i += FunAES.kBlockSize;
		}
		
		return padding ? getUnpadded (dec) : dec;
	}
	
	function getUnpadded (dec : Bytes) : Bytes
	{
		var padding = dec.get (dec.length - 1);
		return dec.sub (0, dec.length - padding);
	}
	
}
