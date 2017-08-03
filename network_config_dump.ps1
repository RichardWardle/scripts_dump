# You can hard code your list of servers if its easier
#$computers = "dc.example.com","member1.example.com"

# I provided my script with a file that had my servers in a list
$computers  = Get-content C:\computers.txt

$EndindResult = @()

foreach ($ind in $computers)
{
  if (Test-WSMan $ind -ea SilentlyContinue) {
        try
        {
            $Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $ind -EA SilentlyContinue | ? {$_.IPEnabled}    
        }
        catch
        {
            Write-Warning "I could not connect to $ind, please investigate this manually even though Test-WSMan passed"
        }
    
    foreach ($Network in $Networks)
    {            
        
        $IPAddress  = $Network.IpAddress[0]            
        $SubnetMask  = $Network.IPSubnet[0]            
        $DefaultGateway = $Network.DefaultIPGateway            
        $DNSServers  = $Network.DNSServerSearchOrder            
        $MACAddress  = $Network.MACAddress 
        $Description  = $Network.Description
        $SuffixRegistration = $Network.DomainDNSRegistrationEnabled 
        $SuffixSearchOrder = $Network.DNSDomainSuffixSearchOrder       
        If($network.DHCPEnabled) { $IsDHCPEnabled = $true } else { $IsDHCPEnabled = $false }
                     
        $indResult  = New-Object -Type PSObject            
        $indResult | Add-Member -MemberType NoteProperty -Name ComputerName -Value $ind.ToUpper()            
        $indResult | Add-Member -MemberType NoteProperty -Name IPAddress -Value $IPAddress            
        $indResult | Add-Member -MemberType NoteProperty -Name SubnetMask -Value $SubnetMask            
        $indResult | Add-Member -MemberType NoteProperty -Name Gateway -Value $DefaultGateway            
        $indResult | Add-Member -MemberType NoteProperty -Name IsDHCPEnabled -Value $IsDHCPEnabled            
        $indResult | Add-Member -MemberType NoteProperty -Name DNSServers -Value $DNSServers            
        $indResult | Add-Member -MemberType NoteProperty -Name MACAddress -Value $MACAddress 
        $indResult | Add-Member -MemberType NoteProperty -Name SuffixSearchOrder -Value $SuffixSearchOrder
        $indResult | Add-Member -MemberType NoteProperty -Name SuffixRegistration -Value $SuffixRegistration
        $indResult | Add-Member -MemberType NoteProperty -Name Description -Value $Description           
        $EndindResult += $indResult

        }
   }
   else 
        { Write-Warning "I could not connect to $ind using Test-WSMan, please investigate this manually" }
}

$EndindResult | ft -autosize
