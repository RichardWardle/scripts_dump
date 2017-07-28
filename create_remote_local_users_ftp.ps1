Param(
  [Parameter(Mandatory=$true)]
  [string]$user,

  [Parameter(Mandatory=$true)]
  [string]$pass
)

$passSecure = ConvertTo-SecureString "$pass" -AsPlainText -force
$folder="D:\ftp_users"
$fullPath="$folder\$user"
[string[]]$servers = "member1","member2"

$creds = get-credential -username administrator -message "for script connections" #you will be asked for your password here you can follow https://blog.kloud.com.au/2016/04/21/using-saved-credentials-securely-in-powershell-scripts/ for instructions on reading password from file
$sess = New-PSSession -ComputerName $servers -Credential $creds

try
{
    $usersCheck = Invoke-Command -session $sess -ScriptBlock { get-localuser -Name $args[0] -ea SilentlyContinue | select-object -Property name,enabled } -args $user
    
    if ($usersCheck.count -gt 0 ) { Write-Warning "The user exsists on the below systems, please manually investigate this" ; Exit 2}
    else
    {
         Invoke-Command -session $sess -ScriptBlock `
         {
            #check if the remote side has the correct version of powershell
            if (-not ($PSVersionTable.PSVersion.Build -gt 5.1)) {Write-warning "These features are only available in 5.1 and above"; Exit 2}

            #Creates the user in the local system
            New-LocalUser -AccountNeverExpires -UserMayNotChangePassword -PasswordNeverExpires -name $args[0] -Password $args[1] -ErrorAction stop
            
            #Creates the folder for the user
            if (-not (Test-path $args[3])) 
            { 
                New-Item -ItemType directory -Path $args[3] -Force | out-null
            }
            
            #sets the ACL on our FTP folder that we created above
            $currentACLSet = Get-Acl $args[3]
            $AddACL = New-Object system.Security.AccessControl.FileSystemAccessRule($args[0], "ReadAndExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
            $currentACLSet.addaccessrule($AddACL)
            Set-Acl $args[3] $currentACLSet | out-null

         } -args $user,$passSecure,$folder,$fullPath
    }
    Remove-PSSession -Session $sess
}
catch
{
    write-output $_.Exception.Message
    Exit 2
}
