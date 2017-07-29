Param(
   [Parameter(Mandatory=$true)]
   [string]$OU,

   [Parameter(Mandatory=$false)]
   $outputloc = "C:\results.csv"

)

#list of hotfixes i found from the internet - may be out of date currently or I might have missed one, I believe win10 and 2016 come prepatched now!
[string[]]$hotfixes = "KB4012212", "KB4012213", "KB4012214", "KB4012215", "KB4012216", "KB4012217", "KB4012220", "KB4012598", "KB4012606", "KB4013198", "KB4013429", "KB4015217", "KB4015219", "KB4015221", "KB4015438", "KB4015549", "KB4015550", "KB4015551", "KB4015554", "KB4016635", "KB4019215", "KB4016636", "KB4016637", "KB4019472", "KB4019473", "KB4019474", "KB4079472","KB4016871", "KB4019216", "KB4019264"

#creates by default array for searching through
$outputArray = @()

try 
{
    # Get a list of computers in OU specified, i do not check cluster objects incase they are in the OU for some reason
    $computers = get-adcomputer -Filter 'servicePrincipalName -NotLike "*MSClusterVirtualServer*"' -SearchBase $OU -ea stop

    # If you dont want to query AD but provide a list of computers, you will also need to change $OU to be a NON MANDATORY paramter or you could swap C:\computers.txt with $OU and just provide file location in OU space
    # $computers = get-content C:\computers.txt

    if ($computers.count -eq 0 ){ Write-error "There are no computers in $OU - please try again"}

    foreach ($indComp in $computers)
    {
        Write-Output "Checking $($indComp.DNSHostName)"
        #Checks if i can connect to the computer, important given get-hotfix doesnt seem to properly handle -ea silentlycontinue or ignore
        if (Test-WSMan $indComp.DNSHostName -ea ignore)
        {
            #Checks the patch is currently installed against the machine
            $results = Get-HotFix -ComputerName $indComp.DNSHostName -id $hotfixes -ea SilentlyContinue # | select -Property pscomputername,description,hotfixid,installedby,installedon
            $bootTime = Get-CimInstance -ClassName win32_operatingsystem -ComputerName $indcomp.DNSHostName -ea SilentlyContinue | select lastbootuptime
            if ($results)
            {
                ##gets the bootime of box, checks if we had a reboot since installed (true if yes), creates a two dimensional array
                $rebootSinceInstall = ([datetime]$bootTime.lastbootuptime -gt [datetime]$results.InstalledOn)
                $outputArray += ,(($indcomp.DNSHostName), $results.description, $results.hotfixid,$results.installedby,$results.InstalledOn,$bootTime.lastbootuptime,$rebootSinceInstall, "Patch Installed")
            }
            else
            {
                # Puts the results int two dim array with N/A since patch not installed, you will get to this part if you cant connect or the server is down

                $outputArray += ,(($indComp.DNSHostName), "N/A", "N/A","N/A","N/A",$bootTime.lastbootuptime,"N/A","No Patch  Installed")
            }
        }
        else
        {
            # I cant connect so output this
            $outputArray += ,(($indComp.DNSHostName), "N/A", "N/A","N/A","N/A","N/A","N/A","Failed to connect")
        }
    }
     #Output my array with information to the computer, if you are running this script multiple times over (e.g. providing a different OU each time) you can use -append so you dont override the contents
     #I deliberatley do not put headers on this since you might use the append functinoality
     $outputArray | % { $_ -join ','} |  out-file $outputloc
     Write-Output "I have finished completing my script and your file is located at: $outputloc, the format of the output is:"
     Write-Output "Hostname, Description of Patch, Hotfix ID from list installed, Who installed it. When it was installed, last time server was rebooted, have we had a reboot since installed (true or false) and a message such as patch installed, not installed or could not connect"
}
catch
{   
    Write-Error "Run Error: $($_.Exception.message | format-list -force)"
    Exit 3
}
