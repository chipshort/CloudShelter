# CloudShelter

**WARNING: THIS IS NOT READY TO USE. IT PROBABLY CONTAINS BUGS AND DOES NOT USE BLOCK CHAINING YET.**

CloudShelter allows you to encrypt files using AES. It can automatically upload said files to or download them from Google Drive or Dropbox. It can also list encrypted files you stored on these hosters.
It also contains an unfinished integration of http://weiyun.com/ which is a chinese cloud provider without any API whatsoever. The current implementation might not be up to date or usable, as it is based on reverse engineering the Web Interface, but Google Drive and Dropbox use the official REST APIs and should work.
CloudShelter also allows to "stream" your encrypted videos from said hosters by downloading and encrypting them on the fly.

### TL;DR

CloudShelter can upload files to a cloud hoster, handling encryption on its own.

Usage:
```
cloudshelter encrypt FILE PASSWORD
	Encrypts FILE (if FILE is a folder, the foldername and all its files are encrypted)
cloudshelter decrypt FILE PASSWORD
	Decrypts FILE
cloudshelter upload SRCFILE DSTPATH SERVICE PASSWORD
	Encrypts and uploads SRCFILE to DSTPATH on SERVICE
cloudshelter download SRVPATH DSTFILE SERVICE PASSWORD
	Downloads and decrypts SRVPATH from SERVICE to DSTFILE
cloudshelter stream SRVPATH SERVICE PASSWORD
	Streams SRVPATH from SERVICE and opens it with the default program (make sure it supports streaming)
cloudshelter rename OLDPATH NEWPATH SERVICE PASSWORD
	Moves OLDPATH hosted on SERVICE and moves it to NEWPATH
cloudshelter delete PATH SERVICE PASSWORD
	Deletes PATH hosted on SERVICE
cloudshelter files SERVICE PASSWORD
	Prints all files on SERVICE in json format
cloudshelter setup SERVICE
	Sets up SERVICE for future usage (getting access permission, etc...)

List of supported SERVICES: 
	GDrive
	Dropbox
```
