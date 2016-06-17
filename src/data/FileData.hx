package data;

/**
 * ...
 * @author Christoph Otter
 */
class FileData
{
	public var id : String;
	public var path : String;
	public var properties : Array<Dynamic>;
	public var fileSize : Int;
	//public var parts = 0; //needed for Weiyun
	
	public var hoster : String;
	
	//icon?
	function new ()
	{
	}
	
	public static function getNameOfWFile (file : WFile) : String
	{
		var name = file.filename;
		return name.substring (0, name.lastIndexOf (";")); //trim away counter
	}
	
	public static inline function getNumOfWFile (file : WFile) : Int
	{
		var name = file.filename;
		var f = name.substring (name.lastIndexOf (";") + 1, name.length); //fetch counter
		
		return Std.parseInt (f);
	}
	
	/**
	 * Takes an ordered Array<WFile
	 * @return a FileData combining the parts of the File
	 * @return
	 */
	/*public static function fromWFiles (files : Array<WFile>) : FileData
	{
		var data = new FileData ();
		
		data.path = getNameOfWFile (files[0]);
		
		data.properties = [];
		data.hoster = "Weiyun";
		data.fileSize = 0;
		data.parts = files.length;
		data.id = "";
		
		for (file in files) {
			data.id += file.file_id + "/";
			data.fileSize += file.file_size;
		}
		data.id = data.id.substr (0, data.id.length - 1);
		
		
		return data;
	}*/
	
	public static function fromWFile (file : WFile) : FileData
	{
		var data = new FileData ();
		data.id = file.file_id;
		data.path = file.filename;
		data.properties = [];
		data.fileSize = file.file_size;
		data.hoster = "Weiyun";
		
		return data;
	}
	
	public static function fromGFile (file : GFile) : FileData
	{
		var data = new FileData ();
		data.id = file.id;
		data.path = file.title;
		data.properties = file.properties;
		data.fileSize = file.fileSize;
		data.hoster = "GDrive";
		
		return data;
	}
	
	public static function fromDFile (file : DFile) : FileData
	{
		var data = new FileData ();
		data.id = file.path;
		data.path = file.path;
		data.properties = [];
		data.fileSize = file.bytes;
		data.hoster = "Dropbox";
		
		return data;
	}
	
	public function toGFile () : GFile
	{
		var file : GFile = {
			id: id,
			fileSize: fileSize,
			title: path
		}
		
		return file;
	}
	
	public function toDFile () : DFile
	{
		var file : DFile = {
			path: id,
			bytes: fileSize
		}
		
		return file;
	}
}

typedef GFile = {
	?id : String,
	?iconLink : String,
	title : String,
	?mimeType : String,
	?labels : { trashed : Bool },
	?parents : Array<{ id : String, ?isRoot : Bool }>,
	?properties : Array<GProperty>,
	?fileSize : Null<Int>
}

typedef GProperty = {
	key : String,
	value : String,
	?visibility : String
}

typedef DFile = {
	path : String,
	?icon : String,
	bytes : Int,
	?contents : Array<DFile>
}

typedef WFolder = {
	dir_key : String,
	dir_name : String
}

typedef WFile = {
	file_id : String,
	file_md5 : String,
	file_sha : String,
	file_size : Int,
	filename : String
}

/*typedef FileData = { //TODO: finish
	id : String,
	?iconLink : String,
	title : String,
	filePath : String,
	?properties : Array<GProperty>,
	?fileSize : Null<Int>
}*/