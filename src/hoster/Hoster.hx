package hoster;
import data.FileData;
import haxe.Json;
import oauth.BodyRequest;
import oauth.Client;
import oauth.Consumer;
import oauth.OAuth2;
import oauth.Tokens.OAuth2AccessToken;
import oauth.Tokens.RefreshToken;
import sys.FileSystem;
import sys.io.File;
import util.System;

/**
 * ...
 * @author Christoph Otter
 */
interface Hoster
{
	public function getFiles () : Map<String, FileData>;
	public function streamFile (srvPath : String) : Void;
	public function downloadFile (srvPath : String, dstFile : String, bufferSize : Int = 48000000) : Void;
	public function uploadFile (file : String, dstPath : String) : Void;
	public function renameFile (file : String, newFile : String) : Void;
	public function deleteFile (file : String) : Void;
	public function setup () : Void;
}

/**
 * ...
 * @author Christoph Otter
 */
class OAuthHoster
{
	var signupUrl : String;
	var tokenUrl : String;
	var redirectUrl : String;
	
	var apiKey : String;
	var secretKey : String;
	var scopes : String;
	
	var tokenFile : String;
	
	var client : Client;
	var crypto : Crypto;
	
	public function new (c : Crypto, saveFile : String, signUrl : String, tUrl : String, redUrl : String, clientId : String, secretId : String, ?scope : String)
	{
		crypto = c;
		tokenFile = saveFile;
		
		signupUrl = signUrl;
		tokenUrl = tUrl;
		redirectUrl = redUrl;
		
		apiKey = clientId;
		secretKey = secretId;
		scopes = scope;
	}
	
	public function setup () : Void
	{
		if (FileSystem.exists (tokenFile))
			login ();
		else
			signup ();
	}
	
	function signup () : Void
	{
		//open authentication site
		System.openUrl (OAuth2.buildAuthUrl (signupUrl, apiKey, {
			redirectUri: redirectUrl,
			scope: scopes,
			state: OAuth2.nonce()
		}));
		
		//wait for code
		Sys.println ("Enter Code:");
		var code = Sys.stdin ().readLine ();
		
		client = OAuth2.connect (new Consumer (apiKey, secretKey));
		client = getAccessToken2 (tokenUrl, code, redirectUrl);
		
		saveToken ();
	}
	
	function saveToken () : Void
	{
		var token = if (client.refreshToken != null)
			client.refreshToken.token;
		else
			client.accessToken.token;
		
		File.saveContent (tokenFile, token);
	}
	
	function login () : Void
	{
		try {
			if (client != null) return;
			client = OAuth2.connect (new Consumer (apiKey, secretKey));
			
			var token = File.getContent (tokenFile);
			client.refreshToken = new RefreshToken (token);
			client = client.refreshAccessToken (tokenUrl);
			
			saveToken ();
		}
		catch (e : Dynamic) {
			signup (); //we failed, ask for permission again
		}
	}
	
	function request (uri : String, method = "GET", ?data : Dynamic, ?dataFormat : DataFormat, ?additionalHeaders : Map<String, String>) : BodyRequest
	{
		var req = new BodyRequest (client.version, uri, client.consumer, client.accessToken, method, data, dataFormat);
		if (client.version.match (V1)) req.sign ();
		
		if (additionalHeaders != null)
			req.additionalHeaders = additionalHeaders;
		
		req.sendRequest ();
		return req;
	}
	
	public function getAccessToken2 (uri : String, code : String, redirectUri : String, ?post : Bool = true) : Client
	{
		if (!client.version.match (V2)) throw "Cannot call an OAuth 2 method from a non-OAuth 2 flow.";
		
		var data = {
			code: code,
			client_id: client.consumer.key,
			client_secret: client.consumer.secret,
			redirect_uri: redirectUri,
			grant_type: "authorization_code"
		};
		
		var result = jsonToMap (jsonRequest (uri, post ? "POST" : "GET", data, PARAMS));
		
		if (!result.exists ("access_token")) throw "Failed to get access token.";
		
		var c = new Client (client.version, client.consumer);
		c.accessToken = new OAuth2AccessToken (result.get("access_token"), Std.parseInt(result.get("expires_in")));
		if (result.exists("refresh_token")) c.refreshToken = new RefreshToken(result.get("refresh_token"));
		return c;
	}
	
	inline function jsonToMap (json:Dynamic) : Map<String, String> {
		var map = new Map<String, String> ();
		
		for (i in Reflect.fields (json)) {
			map.set (i, Reflect.field (json, i));
		}
		
		return map;
	}
	
	inline function jsonRequest (uri : String, method = "GET", ?data : Dynamic, ?dataFormat : DataFormat, ?additionalHeaders : Map<String, String>) : Dynamic
	{
		return Json.parse (request (uri, method, data, dataFormat, additionalHeaders).responseData.toString ());
	}
	
	function generateRange (begin : Int, end : Int, ?fileSize : Null<Int>) : String
	{
		if (fileSize != null)
			return "bytes " + begin + "-" + end + "/" + fileSize;
		else
			return "bytes=" + begin + "-" + end;
	}
	
}
