package oauth;

import haxe.Http;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.Json;
import oauth.Tokens.AccessToken;

@:fakeEnum enum DataFormat {
	JSON;
	PARAMS;
	BYTES;
}

/**
 * A modified version of oauth.Request
 * @author Christoph Otter
 */
class BodyRequest extends Request
{
	public var additionalHeaders = new Map<String, String> ();
	public var requestType : String = "GET";
	public var dataFormat : DataFormat;
	
	public var responseHeaders : Map<String, String>;
	public var responseData : Bytes;

	public function new (version : OAuthVersion, uri : String, consumer : Consumer, token : AccessToken, type = "GET", ?data : Dynamic, ?dataFormat : DataFormat, ?extraOAuthParams : Dynamic)
	{
		super (version, uri, consumer, token, type == "POST", data, extraOAuthParams);
		this.requestType = type;
		this.dataFormat = dataFormat;
	}
	
	function bodyJson () : String
	{
		return Json.stringify (data);
	}
	
	override function postDataStr () : String
	{
		var buf = new StringBuf();
		
		var first = true;
		for (i in Reflect.fields (data)) {
			var fieldData = Reflect.field (data, i);
			
			if (fieldData != null) {
				if (!first)
				buf.add('&');
				buf.add (Request.encode (i) + "=" + Request.encode (fieldData));
				first = false;
			}
		}
		
		return buf.toString();
	}
	
	public function sendRequest () : Bytes
	{
		var h = new Http (uri ());
		#if js
		h.async = false;
		#end
		var authorizationHeader = composeHeader ();
		if (authorizationHeader != "")
			h.setHeader ("Authorization", authorizationHeader);
		
		if (data != null)
			switch (dataFormat) {
				case PARAMS:
					h.setHeader ("Content-Type", "application/x-www-form-urlencoded");
					h.setPostData (postDataStr ());
				case JSON:
					h.setHeader ("Content-Type", "application/json");
					h.setPostData (bodyJson ());
				case BYTES:
					h.setHeader ("Content-Type", "application/octet-stream");
					h.setPostData (data);
			}
		
		for (key in additionalHeaders.keys ()) {
			h.setHeader (key, additionalHeaders.get (key));
		}
		
		var bytesOutput = new haxe.io.BytesOutput();
		h.onStatus = function (status : Int) {
			var stat = Std.string (status);
			if (stat.charAt (0) == "4" || stat.charAt (0) == "5")
				throw "Request error: " + stat;
		}
		h.customRequest (post, bytesOutput, null, requestType);
		
		responseData = bytesOutput.getBytes ();
		responseHeaders = h.responseHeaders;
		
		return responseData;
	}
	
	
}
