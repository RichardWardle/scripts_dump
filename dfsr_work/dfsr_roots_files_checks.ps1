
$global:total_errors=0
$append="c$\dfsroots"
[string[]]$roots = \\"server1\","\\server2\"

#This function goes through the passed location and checks to see if there are any files in here. It will not alert to empty directories or directories that are not classified as reparse points
#the files are then written to output with location, created date, last accessed, length and owner
function Get-FilesInRoot($location)
{
    $members = (get-childitem $location)
    foreach ($indLoc in $members)
    {
        $temp = $indLoc
        if ($($indLoc.Attributes -match "ReparsePoint")) {} #empty since we dont want to go down this folder since it leads to actual files
        elseif ($($indLoc.Attributes -match "Directory")) {Get-FilesInRoot($indLoc.FullName)} #loop down through this directory
        else 
        { 
            Write-Output "   File: $($indLoc.FullName), Created: $($indLoc.CreationTime), LastAccessed: $($indloc.LastAccessTime), Length (Bytes): $($indLoc.Length) Owner: $((get-acl $indLoc.FullName -ErrorAction SilentlyContinue).owner)"
            $global:total_errors++
        }
    }
}

#main loop to go and get the root DFSN and then check for any files. We will stop immediatley if we have any issues
try 
{
    #stores all the roots and then goes through each one. If you want to only check a specific root you could pass the parameter in here if you want or specify a domain other than the context of who is running this script
    #we then loop through each root and check to see if it as any files using a recursive loop inside Get-FilesInRoot function
    #$roots= Get-DfsnRoot -Domain $env:USERDNSDOMAIN -ErrorAction stop
    foreach ($indRoot in $roots)
    {
        #$path = $indRoot.Path
        $path="$indRoot$append" 
        Write-Output "Check DFSN: $path"
        Get-FilesInRoot($path)
        Write-Output ""
    }

    #if you want to use this with sensu you can 
    if ($global:total_errors -gt 0) {Exit 2} else {Exit 0}
}
catch
{
    Write-Output "Run Error: $($_.Exception|format-list -force)"
    Exit 1
}
