package util;
import sys.net.Host;
import sys.net.Socket;

/**
 * FTP frontend for CloudShelter
 * UNFINISHED
 * @author Christoph Otter
 */
class FTPServer
{
	var client : Socket;
	var ended = false;
	
	//http://old.haxe.org/doc/neko/client_server
	//http://www.dailyfreecode.com/code/ftp-client-server-1250.aspx
	public function new ()
	{
		var s = new Socket ();
		s.bind (new Host ("localhost"), 5000);
		s.listen (1);
		
		while (true) {
			client = s.accept ();
			client.write ("220 FTP Server ready.");
			
			while (!ended) {
				readCommand (client.input.readLine ());
			}
			//ended = false;
			client.close ();
		}
	}
	
	public function readCommand (line : String)
	{
		var cmd = line.split (" ");
		
		switch (cmd[0])
		{
			case "USER":
				client.write ("331 Hello");
			case "PASS":
				client.write ("230 Login successful");
			case "SYST":
				client.write ("215 UNIX Type: L8"); //TODO: change
			case "FEAT":
				client.write ("211-Extensions supported:\r\n PASV\r\n211 End.");
			case "PWD":
				client.write ("257 \"/\" is your current location"); //TODO: change
			case "TYPE":
				if (cmd[1] == "I") {
					client.write ("200 TYPE is now 8-bit binary");
					//TODO: save this somewhere
				}
				else if (cmd[1] == "A") {
					//ASCII?
				}
			case "PASV":
				//TODO: create socket and close after one command
				client.write ("227 Entering Passive Mode (127,0,0,1,215,121)");
			case "LIST":
				
			case "QUIT":
				ended = true;
			case "REIN":
				ended = true;
				//TODO: restart
			case "
			
			default:
				client.write ("500 Command not understood.");
		}
	}
	
	
	
}
