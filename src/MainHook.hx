package;

/**
 * This is used to replace the standard Haxe MainHook
 * It is because WinForms needs [System.STAThread] meta
 * @author Christoph Otter
 */
@:keep
class MainHook
{
	@:meta(System.STAThread)
	public static function Main () : Void
	{
		cs.Boot.init ();
		untyped CloudShelter.main ();
	}
	
}
