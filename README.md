# scripts_dump
Dumping ground for a variety of scripts


### running_procs_remote.ps1
We had a variety of applications that ran as executables on the desktop, that you couldnt interact with remotley. To audit these where a pain, finding out what servers ran what applications, from where and what version it was running. This script will go through the computers in computers.txt. It will get the processes running as per what regex you provide in $processes and dump this to results.txt. You can then apply your business logic there OR even better is script further functionality. You should also change the username in there to be the one your run scripts under, I have left a fake on in there.

### create_remote_local_users_ftp.ps1
To provide FTP services to clients we used to run two servers in different locations that were not domain joined, when we wanted to add users we would go create a local user with the same user/pass on both and give that user READ only permissions and let the folder take inherited permissions from the parent (this is for our other applications to write into this folder), IIS handled the FTP component and mapped them to a specific folder. 

5.1 introducted new-localuser, to automate this the simple script connects to the servers in $servers, and creates a local user using the -user and -pass paramters (i do not check password complexity so you need to ensure it matches or it will fail further in). It then creates a folder which is there username in $folder and sets them to have READ permissions.

Note - you are required to enter two passwords, one for the user which is passed as a variable into the script -pass. The other will be a prompt to type it in, this is the same password used for authenticating to both servers. You could add another paramter called -serverPass and then do some thing like: $serverPassSecure = ConvertTo-String "$serverPass" -AsPlainText -Force and then pass that as -password $serverPassSecure in get-credential

### wannacry_check.ps1
This script checks a list of servers from a specified OU (can be modified to take from a file if needed) and checks if a list of patches are installed and provides some output to a csv file for you to investigate. It was useful for when we had to check if all our servers were patched with this when some systems (alot) were not connected to a WSUS server or sat out in customer environments. To make it easy you specified an OU or a list of computers and then it would go check if the patch was installed, not installed OR if you could not connect. We also needed to know if the patch was installed if we had a reboot for it to take effect.

The script will strip out cluster objects for you in the AD query against the get-adcomputer query. You can specify the OU to check with the -OU paramter and the -outputloc will allow you to output your results. Since i only check one OU you could write a script that loops through a list of OU's and passes each OU to this script. You will need to use -append on the out-file section otherwise you will overwrite each time you call the script. This could be modified to check for any series of patches just change the $hotfixes to what you want, alternativley if you want add it as a paramter and you could script it all!

Note: I think the patches on this are up to date but it may not be I tried to cover all inc win7 etc
