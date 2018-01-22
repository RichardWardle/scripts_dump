# scripts_dump
Dumping ground for a variety of scripts

### running_procs_remote.ps1
We had a variety of applications that ran as executables on the desktop, that you couldnt interact with remotley. To audit these where a pain, finding out what servers ran what applications, from where and what version it was running. This script will go through the computers in computers.txt. It will get the processes running as per what regex you provide in $processes and dump this to results.txt. You can then apply your business logic there OR even better is script further functionality. You should also change the username in there to be the one your run scripts under, I have left a fake on in there.

### create_remote_local_users_ftp.ps1
To provide FTP services to clients we used to run two servers in different locations that were not domain joined, when we wanted to add users we would go create a local user with the same user/pass on both and give that user READ only permissions and let the folder take inherited permissions from the parent (this is for our other applications to write into this folder), IIS handled the FTP component and mapped them to a specific folder. 

5.1 introducted new-localuser, to automate this the simple script connects to the servers in $servers, and creates a local user using the -user and -pass paramters (i do not check password complexity so you need to ensure it matches or it will fail further in). It then creates a folder which is there username in $folder and sets them to have READ permissions.

Note - you are required to enter two passwords, one for the user which is passed as a variable into the script -pass. The other will be a prompt to type it in, this is the same password used for authenticating to both servers. You could add another paramter called -serverPass and then do some thing like: $serverPassSecure = ConvertTo-String "$serverPass" -AsPlainText -Force and then pass that as -password $serverPassSecure in get-credential

### azure/azure_local_cleanup.py

This takes a yaml config file called settings.conf (example one provided). You then provide your retention in settings and it will remove any file older than that in your azure storage or/and in local files provided. Some error handling but it logs everything to file that you can parse or modify as required. 

### wannacry_check.ps1
This script checks a list of servers from a specified OU (can be modified to take from a file if needed) and checks if a list of patches are installed and provides some output to a csv file for you to investigate. It was useful for when we had to check if all our servers were patched with this when some systems (alot) were not connected to a WSUS server or sat out in customer environments. To make it easy you specified an OU or a list of computers and then it would go check if the patch was installed, not installed OR if you could not connect. We also needed to know if the patch was installed if we had a reboot for it to take effect.

The script will strip out cluster objects for you in the AD query against the get-adcomputer query. You can specify the OU to check with the -OU paramter and the -outputloc will allow you to output your results. Since i only check one OU you could write a script that loops through a list of OU's and passes each OU to this script. You will need to use -append on the out-file section otherwise you will overwrite each time you call the script. This could be modified to check for any series of patches just change the $hotfixes to what you want, alternativley if you want add it as a paramter and you could script it all!

Note: I think the patches on this are up to date but it may not be I tried to cover all inc win7 etc

### basic_reg_set.ps1
We had a range of settings that we applied in the registry for our machines: autologin settings (everything ran in console), network settings and other secret ones! This allows you to pass the path, key name, value expected, type and it will check if that exsists and is set correct. If not it will create it and set the value for you. It is super easy to add to this as you jsut pass your settings to the checkRegistry function and it will handle the rest for you.

This runs in two modes that is handled via -checkonly [bool]. If its false (default) it will tell you if the setting is set correctly or not (green = good, red = bad). If you make it true then it will check to see if its set correctly and if not it would set it for you (the line will then be magenta - if you ran the script again immediatley it would flag as green)

If you had to apply a setting to all network cards you could right a function that iterates through all the folders in the network settings registry path and then call the checkRegistry function across to set the values you want!

### network_config_dump.ps1
We had a range of servers that were having there subnet moved from 192.168.5.0/24 to 192.168.4.0/23. We had to change every subnet on all those servers to ensure that it could properly talk to the extended subnet (aka 192.168.5.4/24 had issues talking to 192.168.4.230/23). This script pulled the IP settings for some configurations and allowed us to find which servers we still had to change. We could use it to find systems that had been given out there IP address as per DHCP so we could check to see if there was a reservation for the MAC address or if it could randomly change IP address. Just supply C:\computers.txt with your servers you want to query 

### sensu_streamlined_install.ps1
This auto installs sensu on your computer. Requires sensu.msi to be in the C:\ and the C:\opt to not exsist otherwise it will stop. You can change some of the variables inside as required. I will update this to handle passing rabbit server and other details via paramters. It should also be able to dynamically pull a subscriptions list or have one passed to it (auto adding the computer hostname for you so remediation will work). The final problem I have not decided on is the IP address that it should use, currently it pulls the first IP address that it finds regardless of what this is which is not ideal (I should query DNS for this or have it as a paramter that can be passed)!!

### sensu_uninstall.ps1
Basic uninstall script for sensu. Place the name or IP of your server in $sensu_server (inc port). This script was designed to be used with sensu_streamlined_install.ps1. The script does no error handling and blows away C:\opt, it also tries to post a delete message to the sensu server for you to clean it up

### generate_key_csr
Basic information (I always seem to forget) for generating my certificate keys/CSR and then pumping it into AD. It also has the config file for specifying the SAN and CN names since they need to be in there so you dont see errors about them missing!

### map_ad_domains.ps1
Working with multiple AD controllers and domains isnt the most fun. To help understand a new environment from a where is what in where I wrote this powershell script. You simply run it at the top of your forest and it will map out the forests you have a trust with, it will then also map the subdomains including any trusts they have and domain controllers. It will also help point out the 2 FSMO roles for the forest and then the 3 FSMO roles per domain/sub domain that will be there. This is a pointless script though, Microsoft AD topology toolset will map out Active Directory/Exchange nicely for you all into visio (its like black magic!), link is here: https://www.microsoft.com/en-au/download/details.aspx?id=13380

### visual_studio_installs.ps1
Dirty script that quickly installed certain visual studio code silently for you depending on 64 or 32 bit (if your 64 bit it also installed 32bit). The files must be named vcredit_ARCH_YYYY.exe and be in visual folder located in where script is being run.

### dfsr_work\dfsr_roots_files_check.ps1
Microsofts best practise is to not have any files stored in the your DFSN roots. This is because they are stored on that namespace server in C:\DFSRoots\ (by default), this means that they wont be available if that namespace server is down, given that its also on the C:\ one could theoretically drop data in there clogging up the OS volume and potentially bringing down the server or other core applications that are running it (namely if this is a multipurpose server in a smaller environment). This script will check all your dfsn roots in your domain and then tell you if you have any files there that should not be, including who owns them, size, last access date etc. I created this so i could easily get a list across a large number of DFSN with a complex heirachy across multiple DFSN servers distributed globally. To stop this though you should ensure users can not write to the DFSN root by giving them read only permissions ( To change Click Namespaces -> DFSN Root -> Namespace Server Tab -> right click on each target and click properties, go into Share permissions and set READ for everyone. NOTE: This will not change the NTFS permissions on the target folders just who can write into the DFSN root section). This is what happens when you are bored on Friday nights...
