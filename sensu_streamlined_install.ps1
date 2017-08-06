
$sensufile = "C:\sensu.msi"
$fullComputer = $env:COMPUTERNAME + "." + $env:USERDNSDOMAIN
$grablocal_ip = Get-WmiObject Win32_NetworkAdapterConfiguration -Property IPAddress | ? { $_.IPAddress }
[string]$local_ip = $grablocal_ip[0].IPAddress
$rabbit_ip = '192.168.4.230'
$subs_list = "cluster", "prod", $fullComputer, "windows-hosts"

#transport configuration for the client to rabbitmq, you can use SSL certs if you want but you will need to ensure they are copied into where ever you place them!
#I have left $ip as a passable paramter since the sensu rabbitmq server may differ if each datacentre runs its own local instances so you can leverage the
#datacentre section in uchiwa. My password and ssl settings are normally the same globally
$transport_config = 
    @{
        rabbitmq = @{
            host = $rabbit_ip
            vhost = '/sensu'
            user = 'sensu'
            password = 'secret'
            #ssl = @{
            #    cert_chain_file = ''
            #    private_key_file  = ''
            #        }
        }
        transport = @{ 
            name = 'rabbitmq'
            reconnect_on_error = 'true'
        }
    } |  convertto-json

#$transport_config

#Configuration for the actual client
$sensu_config = 
    @{
        client = @{ 
            name = $fullComputer
            address = $local_ip
            subscriptions = $subs_list
        }
    } |  convertto-json

#$sensu_config

#This checks if C:\opt exsists, if it does then sensu may already be installed so we will exit otherwise continue
if (Test-Path C:\opt) 
{
    Write-Warning "Sensu may be installed since C:\opt exsists, please remove it as this is the default location or rename it"
    Exit 2
}
else
{
    #Check that our file exsists for installed
    if (Test-Path $sensufile)
    {
        Write-Output "Installing Sensu"
        msiexec /i $sensufile /quiet

        Write-Output "Register Sensu Service"
        cmd /C "sc create sensu-client start= delayed-auto binPath= c:\opt\sensu\bin\sensu-client.exe DisplayName= "Sensu_Client""

        Write-output "Create Configuration Files for Sensu"
        mkdir C:\opt\sensu\conf.d\
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines("C:\opt\sensu\conf.d\transport_config.json", $transport_config, $Utf8NoBomEncoding)
        [System.IO.File]::WriteAllLines("C:\opt\sensu\conf.d\sensu_config.json", $sensu_config, $Utf8NoBomEncoding)

        Write-output "Ensure Sensu Service is started after waiting for everything to register (30 seconds)"
        Start-Sleep -Seconds 30
        Start-Service -DisplayName "Sensu_Client"

    }
    else
    {
        Write-Warning "The installer for sensu is not available at $sensufile"
        Exit 2
    }
}
