#set variables
$fullComputer = $env:COMPUTERNAME + "." + $env:USERDNSDOMAIN
$sensu_server = "192.168.4.230:4567"
$url = "http://$sensu_server/clients/$fullComputer"

#Uninstall Sensu automatically script

#Stop the service and remove it as a registered service
Stop-Service -DisplayName Sensu_Client -Force
cmd /C "sc delete sensu-client"

#Send a POST message to sensu removing it from there so it doesnt false alarm given we are uninstalling it
#This will only work if you have port 4567 opened from your server-api server which may be a security risk
#in prod i would most likley just manually delete it
curl -Method DELETE $url -usebasicparsing

#Uninstall from computer
$getUninstall = get-WmiObject -Class Win32_Product -Filter "Name = 'Sensu'"
$getUninstall.Uninstall()

#Delete the entire C:\opt folder
rm -path C:\opt -Recurse -Force -ea silentlycontinue
