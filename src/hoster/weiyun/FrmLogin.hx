package hoster.weiyun;

import haxe.io.Path;
import haxe.Json;
import util.System;
/**
 * ...
 * @author Christoph Otter
 */
@:nativeGen class FrmLogin extends cs.system.windows.forms.Form
{
	public static var cookies = new Map<String, String> ();
	static var webMain : cs.system.windows.forms.WebBrowser;
	static var setup = true;
	
	var reqUrl : String;
	var mail : String;
	var password : String;
	
	public function new (user : String, pass : String)
	{
		super ();
		reqUrl = "http://xui.ptlogin2.weiyun.com/cgi-bin/xlogin?appid=527020901&s_url=https%3A%2F%2Fwww.weiyun.com&style=32&border_radius=1&maskOpacity=40&target=self&link_target=blank&hide_close_icon=1";
		mail = user;
		password = pass;
		
		//setup components
		InitializeComponent();
		webMain.Navigate (reqUrl);
	}
	
	function navigating (sender : Dynamic, e : cs.system.windows.forms.WebBrowserNavigatingEventArgs)
	{
		//e.Uri.Host
		if (webMain.Url.Host == "www.weiyun.com")
		{
			//stealing the cookies ;)
			for (cookie in webMain.Document.Cookie.split ('; '))
			{
				var name = cookie.split('=')[0];
				var value = cookie.substring (name.length + 1);
				cookies.set (name, value);
			}
			
			this.DialogResult = cs.system.windows.forms.DialogResult.OK;
		}
	}
	
	@:functionCode("
		var arg = @\"{ window.setTimeout(function () { document.getElementById('switcher_plogin').click(); var f = function () { document.getElementById ('p').value = '\" + password + @\"'; document.getElementById ('u').value = '\" + mail + @\"'; document.getElementById('login_button').click(); }; window.setInterval(f, 3000); }, 1000); }\";
		webMain.Document.InvokeScript (\"eval\", new object[] { arg });")
	function InvokeScript () : Void
	{
	}
	
	function documentCompleted (sender : Dynamic, e : cs.system.windows.forms.WebBrowserDocumentCompletedEventArgs)
	{
		if (webMain.Url.Host == new cs.system.Uri (reqUrl).Host) //login
			InvokeScript ();
	}
	
	
	//DESIGNER CODE FOLLOWING
	
	/// <summary>
	/// Erforderliche Designervariable.
	/// </summary>
	var components : cs.system.componentmodel.IContainer = null;
	
	/// <summary>
	/// Verwendete Ressourcen bereinigen.
	/// </summary>
	/// <param name="disposing">True, wenn verwaltete Ressourcen gelöscht werden sollen; andernfalls False.</param>
	@:overload @:protected override function Dispose(disposing : Bool) : Void
	{
		/*if (disposing && (components != null))
		{
			components.Dispose();
		}*/
		super.Dispose (disposing);
	}
	
	/// <summary>
	/// Erforderliche Methode für die Designerunterstützung.
	/// Der Inhalt der Methode darf nicht mit dem Code-Editor geändert werden.
	/// </summary>
	function InitializeComponent () : Void
	{
		if (setup) webMain = new cs.system.windows.forms.WebBrowser ();
		setup = false;
		SuspendLayout();
		// 
		// webMain
		// 
		webMain.Dock = cs.system.windows.forms.DockStyle.Fill;
		//webMain.IsWebBrowserContextMenuEnabled = false;
		webMain.Location = new cs.system.drawing.Point(0, 0);
		webMain.MinimumSize = new cs.system.drawing.Size(20, 20);
		webMain.Name = "webMain";
		webMain.ScriptErrorsSuppressed = true;
		webMain.Size = new cs.system.drawing.Size(661, 415);
		webMain.TabIndex = 0;
		webMain.add_DocumentCompleted (documentCompleted);
		webMain.add_Navigating (navigating);
		// 
		// frmMain
		// 
		this.AutoScaleDimensions = new cs.system.drawing.SizeF (6, 13);
		this.AutoScaleMode = cs.system.windows.forms.AutoScaleMode.Font;
		this.ClientSize = new cs.system.drawing.Size (661, 415);
		this.Controls.Add(webMain);
		this.Name = "frmMain";
		this.Text = "CloudShelter";
		//this.Opacity = 0;
		this.ShowInTaskbar = false;
		this.ResumeLayout(false);
	}
}