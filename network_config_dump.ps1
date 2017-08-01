# You can hard code your list of servers if its easier
#$computers = "dc.example.com","member1.example.com"

# I provided my script with a file that had my servers in a list
$computers  = Get-content C:\computers.txt

$networks = @()

foreach ($ind in $computers)
{
  if (Test-WSMan $ind -ea SilentlyContinue) {
        try
        {
            $Networks += Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $ind -EA SilentlyContinue | select -property DNSHostName, IPAddress, IPSubnet, MACAddress, DefaultIPGateway, DHCPEnabled | ? {$_.IPAddress}
        }
        catch
        {
            Write-Warning "I could not connect to $ind, please investigate this manually even though Test-WSMan passed"
        }
   }
   else 
        { Write-Warning "I could not connect to $ind using Test-WSMan, please investigate this manually" }
}
#Super lazy here outputting to csv gave me System.String[] since you could have multiple IP's or subnets on a nic
#to avoid this problem i just output to table then into a file in txt and manipulate it in excel
$networks | ft > C:\subnet_results.txt

# Output results to console at the end
$networks 
