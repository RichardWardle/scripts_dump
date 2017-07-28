# Script was aimed to search computers that ran programs on the desktop (e.g. console mode) that had no way of interacting with it
# You need to put all your computers in computers.txt where this script is run. Place your processes you want in $processes, you can use regex given i use the match in where-object
# This then returned an object I can search through and apply business logic although i just output to results.csv

if ( -not (test-path computers.txt -EA silently)) { Write-Warning "The computers.txt does not exsist in $($pwd), Please create it and add your computers on each line"; Exit 1}

$computers = get-content computers.txt
$creds = get-credential -username example\administrator -message "for script connections" #you will be asked for your password here you can follow https://blog.kloud.com.au/2016/04/21/using-saved-credentials-securely-in-powershell-scripts/ for instructions on reading password from file
$sess = New-PSSession -ComputerName $computers -Credential $creds
$processes="ftp_checker|feedReader|web_app"

try
{
    #foreach ($ind in $computers) {if (-not (Test-WSMan $ind)) {Write-Warning "I could not connect to $ind, I am exiting here"; Exit 3}}
    $results = invoke-command -Session $sess -ScriptBlock { get-process | Where-Object -Property ProcessName -match $args[0]| select -Property id, ProcessName, StartTime, ProductVersion, FileVersion, Path } -args $processes
    
    ## Apply business logic here for further processing ##
    $results | Export-Csv -Path results.txt
    ## Apply business logic here for further processing ##
}
catch
{
    Write-Error Error: $_.Exception.Message
    Exit 2
}
