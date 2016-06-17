package hoster;
import com.fundoware.engine.crypto.aes.FunAES;
import cpp.Void;
import haxe.Http;
import haxe.Int32;
import haxe.Int64;
import haxe.io.Bytes;
import haxe.Json;

/**
 * UNFINISHED
 * @author Christoph Otter
 */
class Mega
{
	var seqno : UInt;
	var sid = "";

	public function new ()
	{
		seqno = Std.int (Math.random () * (0xFFFFFFFF : UInt));
		
		//trace (seqno);
		var data = encodeString ("test2315p230+#");
		for (d in data) {
			trace (byteToInt (d));
		}
		
		var email = "christophotter@gmail.com";
		var uh = "";
		//array('a' => 'us', 'user' => $email, 'uh' => $uh)
		var res = request ( {
			"a": "us",
			"user": email,
			"uh": uh
		});
		trace (res);
	}
	
	public function request (req : Dynamic) : Dynamic
	{
		var url = "https://g.api.mega.co.nz/cs?id=" + 1582395549;
		if (sid != "") url += "&sid=" + sid;
		
		var http = new Http (url);
		http.setPostData (Json.stringify (req));
		
		var r = null;
		http.onData = function (d : String) {
			r = d;
		};
		http.onError = function (e : String) {
			throw e;
		};
		
		http.request (true);
		
		return Json.parse (r);
	}
	
	/**
	 * @return  a padded version of (str) with a length of a multiple of 4
	 */
	public function encodeString (str : String) : Array<Bytes>
	{
		var padded = StringTools.rpad (str, "\u0000", 4 * Math.ceil (str.length / 4));
		
		var ret = new Array<Bytes> ();
		
		for (i in 0 ... Std.int (padded.length / 4)) {
			var str = padded.substr (i * 4, 4);
			ret.push (Bytes.ofString (str));
		}
		return ret;
	}
	
	function stringhash (s : String, key : Bytes) : String
	{
		var s32 = encodeString (s);
		var h32 = Bytes.alloc (4);
		
		for (i in 0 ... s32.length) {
			h32[i % 4] ^= byteToInt (s32[i]);
		}
		
		var aes = new FunAES (key);
		
		for (i in 0 ... 0x4000) {
			aes.encryptCBC (h32,
		}
		
		return "";
	}
	
	function byteToInt (byte : Bytes, littleEndian = false) : Int
	{
		var ch1 = byte.get (0);
		var ch2 = byte.get (1);
		var ch3 = byte.get (2);
		var ch4 = byte.get (3);
		return littleEndian ? (ch4 << 24) |(ch3 << 16) | (ch2 << 8) | ch1 : (ch1 << 24) | (ch2 << 16) | (ch3 << 8) | ch4;
	}
	
	function aesCbcEncryptA32 (data : Bytes, key : Bytes) : Bytes
	{
		return encodeString ();
	}
	
}