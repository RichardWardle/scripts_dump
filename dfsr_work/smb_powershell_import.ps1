# Grossly stolen again but made some changes around handling the Everyone SID since this did not handle correctly

# ImportShareInfo.ps1
# This script will Import the Shares from a CSV file
# made by ExportShareInfo.ps1 complete with securityInfo
 
###### CHANGE FILESERVER TO SERVER SCRIPT IS RUNNING ON ######
$FileServer = "member5"
 
#Import the CSV file
write-host "Importing the CSV Info"
#CHANGE TO FILEPATH OF CSV
$ShareList = Import-Csv "$env:USERPROFILE\Desktop\export_shares.csv"
write-host "   Complete" -ForegroundColor green
write-host "Sorting share list"
#Sort the Shares
$ShareList = $ShareList | sort-object {$_.name}
write-host "   Complete" -ForegroundColor green
 
# Advanced function: acts like a cmdlet so the ErrorVariable parameter can be used when its called.
# That way, we can throw an error message, trap it from outputting on host, yet
# store it in EV so we can add the error to the "ProblemShares" hash table
Function Check-CleanInput {
    [CmdletBinding()]
    param($arrCSVShareInfo)
    $blnCleanInput = $null
    $blnCleanInput = $true
 
    # used below to check domain, user
    $strThisDomainName = [adsi]''; $strThisDomainName = $strThisDomainName.get("Name")
 
      $arrCSVShareInfo | % {
 
            # Domain
            If ($blnCleanInput -eq $true) {
                If ((($_.domain -match $strThisDomainName) -ne $true) -and (($_.domain -match "builtin") -ne $true)){
                    Trap {Continue;}
                    Throw "The domain name in the CSV file makes the script uncomfortable $($_.domain) x $_"
                    $blnCleanInput = $false
                }
            }
 
            # User checks for username and group names- may need to add things specific to your server
            If ($blnCleanInput -eq $true) {
                If ($_.Domain -eq $strThisDomainName) {
                    $blnDoesUserExist = Check-DoesUserExist ($_.User)
                    If (($blnDoesUserExist -eq $false) -and ($_.User -ne "Everyone")) {
                        #If the user in the CSV isn't a user, check if its a group.
                        $blnDoesGroupExist = Check-DoesGroupExist($_.User)
                        If ($blnDoesGroupExist -eq $false) {
                            Trap {Continue;}
                            Throw "The user in the CSV doesn't exist"
                            $blnCleanInput = $false
                        }
                    }
                }
            }
 
            # Path... RegEx from http://regexlib.com/REDetails.aspx?regexp_id=2285
            If ($blnCleanInput -eq $true) {
                $blnPathValid = ($_.Path -match "^((\\\\[a-zA-Z0-9-]+\\[a-zA-Z0-9`~!@#$%^&(){}'._-]+([ ]+[a-zA-Z0-9`~!@#$%^&(){}'._-]+)*)|([a-zA-Z]:))(\\[^ \\/:*?""<>|]+([ ]+[^ \\/:*?""<>|]+)*)*\\?$")
                If ($blnPathValid -eq $false) {
                    Trap {Continue;}
                    Throw "The share path in the CSV is not a valid Windows share path"
                    $blnCleanInput = $false
                }
            }
 
            # Share Name... RegEx from http://regexlib.com/REDetails.aspx?regexp_id=1145, but modified it to match share name (original was for user name)
            # Share name can't contain :   "/\[]:|<>+=;,?*  can contain: ~`!@#$%^&()_-{}".
            If ($blnCleanInput -eq $true) {
                $blnShareNameValid = ($_.Name -match "(^[A-Za-z0-9~`!@#$%_\^\&amp;\-\.\ \(\)\{\}]{1,80})$")
                If ($blnShareNameValid -eq $false) {
                    Trap {Continue;}
                    Throw "The share name in the CSV is not a valid Windows share name"
                    $blnCleanInput = $false
                }
            }
 
            # AccessMask: Read, Change, Full Control are the only access masks currently supported. If there are any accounts with weird permissions,
            # they wont be created (but will appear in "Problem Shares"). Obviously you can add whatever AM's you want here
            If ($blnCleanInput -eq $true) {
                If (`
                    #ADD OR REMOVE ACCESS MASKS BASED ON YOUR PREFERENCES
                   ($_.AccessMask -ne "1179817") -and ($_.AccessMask -ne "1245631") -and ($_.AccessMask -ne "2032127")) {
                     Trap {Continue;}
                     Throw $_.AccessMask + " is an unsupported access mask"
                     $blnCleanInput = $false
                 }
            }
 
            # Ace Type: 0 is allow, 1 is deny
            If ($blnCleanInput -eq $true) {
                [int]$AceType = $_.AceType
                If (($AceType -ne 0) -and ($AceType -ne 1)) {
                Trap {Continue;}
                Throw "Ace type must be 0 or 1"
                $blnCleanInput = $false
                }
            }
 
            #Ace Flags is a bit mask of values 1, 2, 4, 8, 16 and therefore any combo is between 1 and 31
            #values are here: http://msdn.microsoft.com/en-us/library/aa392711(v=VS.85).aspx
            If ($blnCleanInput -eq $true) {
                [int]$AceFlags = $_.AceFlags
                If (($AceFlags -lt 0) -or ($AceFlags -gt 31)) {
                    Trap {Continue;}
                    Throw "Ace flags must be between 0 and 31"
                    $blnCleanInput = $false
                }
            }
        }
 
    Return $blnCleanInput
}
 
Function Check-DoesSharePathExist($sharePath) {
    $pathExists = $null
    $pathExists = Test-Path $SharePath
    If ($PathExists -ne $true) {
        return $false
    }
    Else {
        Return $true
    }
}
 
Function Check-DoesGroupExist($groupCN) {
    #grab all groups with GID's
    $searchRoot = [ADSI]''
    $searcher = new-object System.DirectoryServices.DirectorySearcher($searchRoot)
    $searcher.filter = "(&(objectClass=group)(CN=" + $groupCN + "))"
    $searchResults = $searcher.findall()
 
    If($searchResults.count -lt 1)
        {$results = $false}
    Else
        {$results = $true}
 
    $searchResults.Dispose()
    $searcher.Dispose()
    $searchResults = $null
    $searcher = $null
 
    Return $results
}
 
Function Check-DoesUserExist($sAMAccountName)   {
 
    $searchRoot = [ADSI]''
    $searcher = new-object System.DirectoryServices.DirectorySearcher($searchRoot)
    $searcher.filter = "(&(objectClass=person)(sAMAccountName=" + $sAMAccountName + "))"
    $searchResults = $searcher.findall()
 
    If($searchResults.count -lt 1)
        {$results =  $false}
    Else
        {$results = $true}
 
    $searchResults.Dispose()
    $searcher.Dispose()
    $searchResults = $null
    $searcher = $null
 
    Return $results
}
 
Function Create-Folder($strFolder)  {
    $results = $null
    $results = $false
 
    If($strFolder -eq $null -or $strFolder -eq "" -or $strFolder -eq $false)
        {$results = $false}
    Else
        {
            If((Test-Path $strFolder) -eq $true)
                {$results = $true}
            Else
                {New-Item $strFolder -itemType Directory}
 
            If((Test-Path $strFolder) -eq $true)
                {$results = $true}
            Else
                {$results = $false}
        }
 
    Return $results
}
 
Function Get-SharePath($shareName)  {
    Trap{continue;}
    $strWMI = $null
    $strWMI = "\\" + $fileserver + "\root\cimv2:win32_share.name='" + $shareName + "'"
    $sharePath = $null
    $sharePath = ([wmi]$strWMI).path
    Return $sharePath
}
 
Function Check-DoesShareExist($shareName)   {
        $shareExists = $null
        $sharePath = $null
        $sharePath = Get-SharePath $shareName
        If($sharePath -eq $false -or $sharePath -eq $null)
            {$shareExists = $false}
        Else
            {$shareExists = $true}
        Return $shareExists
}
 
Function Check-SharePermissions($ShareName, $arrCSVShareInfo) {
    $strWMI = "\\" + $fileServer + "\root\cimv2:win32_LogicalShareSecuritySetting.Name='" + $ShareName + "'"
    $objWMI_ShareSec = [wmi]$strWMI
  $objWMI_SD = $objWMI_ShareSec.invokeMethod('GetSecurityDescriptor',$null,$null)
  $numACEsMatched = 0
  $ExistingShareDACL = $objWMI_SD.Descriptor.DACL
  $DACLlength = $ExistingShareDACL.length
  #Only compare CSV to current DACL if they are the same length
  If ($arrCSVShareInfo.length -eq $DACLlength) {
    $ExistingShareDACL | % {
        For($i = 0;$i -lt $arrCSVShareInfo.length;$i++) {
            #If aone of the ACE's is the same as 1 of the CSV entries in all categories, add 1 to the ACEsMatched
            If(`
            ($_.AccessMask -eq $arrCSVShareInfo[$i].AccessMask)`
            -and ($_.Trustee.Name -eq $arrCSVShareInfo[$i].User)`
            -and ($_.Trustee.Domain -eq $arrCSVShareInfo[$i].Domain)`
            -and ($_.AceFlags -eq $arrCSVShareInfo[$i].AceFlags)`
            -and ($_.AceType -eq $arrCSVShareInfo[$i].AceType)) {
 
                $numACEsMatched++
            }
            }
        }
    }
 
    If ($numACEsMatched -eq $DACLlength) {
        Return $true
    }
    Else {
        Return $false
    }
}
 
Function Fix-SharePermissions ($ShareName, $arrCSVShareInfo) {
    #Create security objects
    $objWMI_NewSD = ([WMIClass] ("\\" + $FileServer + "\root\CIMv2:Win32_SecurityDescriptor")).CreateInstance()
    $objWMI_NewSD.DACL = @()
    $objWMI_NewEmptyACE = ([WMIClass] ("\\" + $FileServer + "\root\CIMv2:Win32_ACE")).CreateInstance()
    $objWMI_NewTrustee = ([WMIClass] ("\\" + $FileServer + "\root\CIMv2:Win32_Trustee")).CreateInstance()
 
    $arrCSVShareInfo | % {
        #fill with CSV permissions
        $objWMI_NewCompleteACE = (Add-PermissionsToACE $_ $objWMI_NewTrustee $objWMI_NewEmptyACE )
        $objWMI_NewSD.DACL += $objWMI_NewCompleteACE.PsObject.BaseObject
    }
 
    $strWMI = "\\" + $fileServer + "\root\cimv2:win32_Share.Name='" + $ShareName + "'"
    $objWMI_ThisShare = [wmi]$strWMI
    $inParams = $objWMI_ThisShare.GetMethodParameters("SetShareInfo")
    $inParams["Access"] = $objWMI_NewSD.PsObject.BaseObject
    #attach new SD to share
    $objWMI_ThisShare.InvokeMethod("SetShareInfo",$inParams,$null)
 
    #Check if permissions are now right
    $blnDoPermsMatch = Check-SharePermissions $ShareName $arrCSVShareInfo
 
    Return $blnDoPermsMatch
}
 
Function VerifyAndFix-ShareInfo {
    [CmdletBinding()]
    param($name, $path, $arrCSVShareInfo)
    $blnerrorsdetected = $null
    $blnErrorsDetected = $false
    $strErrorMsg = $null
 
    $blnCleanInput = Check-CleanInput $arrCSVShareInfo -EV err -EA SilentlyContinue
    If ($blnCleanInput -eq $false) {
        $blnErrorsDetected = $true
        $strErrorMsg = $err
        trap {Continue;}
        throw $strErrorMsg
        return $blnErrorsDetected
        break
    }
 
    $blnPathExist = Check-DoesSharePathExist $path
    If ($blnPathExist -eq $false) {
        $blnPathExist = Create-Folder $Path
        If ($blnPathExist -eq $false) {
            $blnErrorsDetected = $true
            $strErrorMsg = "The file path does not exist and could not be created"
            trap {Continue;}
            throw $strErrorMsg
            return $blnErrorsDetected
            break
        }
    }
 
    # If Share Path exists, share exists
    $blnShareExist = Check-DoesShareExist $name
    If($blnShareExist -ne $false -and $blnShareExist -ne $null) {
        $blnDoPermsMatch = Check-SharePermissions $name $arrCSVShareInfo
        If ($blnDoPermsMatch -eq $false) {
            $blnDoPermsMatch = Fix-SharePermissions $name $arrCSVShareInfo
            If ($blnDoPermsMatch -eq $false) {
                $blnErrorsDetected = $true
                $strErrorMsg = "The share exists, but the permissions do not match the CSV"
                trap {Continue;}
                throw $strErrorMsg
                return $blnErrorsDetected
                break
            }
        }
    }
 
    return $blnErrorsDetected
}
 
Function Add-PermissionsToACE($arrCSVShareInfo, [System.Management.ManagementObject]$objWMI_Trustee, [System.Management.ManagementObject]$objWMI_ACE) {
 
    # Add properties to trustee
  $objWMI_Trustee.Domain = $arrCSVShareInfo.Domain
  $objWMI_Trustee.Name = $arrCSVShareInfo.Name
 
  # Get SID, convert to binary. Reference: http://mow001.blogspot.com/2005/10/getting-and-using-securityprincipal.html

  if ($arrCSVShareInfo.user -ne "Everyone") 
   {
        $strSID = ((new-object System.Security.Principal.NTAccount ($arrCSVShareInfo.domain, $arrCSVShareInfo.user)).translate([System.Security.Principal.SecurityIdentifier]))
   }
   else
   {
        $strSID = ((new-object System.Security.Principal.NTAccount ("", "Everyone")).translate([System.Security.Principal.SecurityIdentifier]))
   }

  [byte[]]$binSID = ,0 * $strSID.BinaryLength
  $strSID.GetBinaryForm($binSID,0)
  $objWMI_Trustee.SID = $binSID
 
  # Add properties to ACE
  $objWMI_ACE.AccessMask = $arrCSVShareInfo.AccessMask
  $objWMI_ACE.AceType = $arrCSVShareInfo.AceType
  $objWMI_ACE.AceFlags = $arrCSVShareInfo.AceFlags
  $objWMI_ACE.Trustee = $objWMI_Trustee.PsObject.BaseObject
 
  Return $objWMI_ACE
}
 
Function Create-ShareFromCSVInfo($Name, $Path, $Description , [System.Management.ManagementObject]$SecurityDescriptor) {
    $results = $null
 
    $objWMI_Share= [WMIClass]("\\" + $FileServer + "\root\CIMv2:Win32_Share" )
  $InParams = $objWMI_Share.GetMethodParameters('Create')
 
  # Fill parameters
  $InParams["Access"] = $SecurityDescriptor.PsObject.BaseObject
  $InParams["Description"] = $Description
  $InParams["Name"] = $Name
  #$InParams["Password"] = [string]
  $InParams["Path"] = $Path
  $InParams["Type"] = "0"
 
  $R = $objWMI_Share.InvokeMethod('Create', $InParams, $Null)
  If ($R.ReturnValue -ne "0") {
    #0 means success, anything else failed
    $results = $false
  }
  Else {
    $results = $true
  }
  Return $results
}
 
########### MAIN ###########
 
#This hash table will hold names of shares with errors.
 
$ProblemShares = @{}
 
#   The sharelist is sorted, so we are basically looking at the share name and seeing if it is the same as the last one.
# If it is, we add it to $arrCSVShareInfo. If it isn't, we pass $arrCSVShareInfo through the necessary functions to
# verify and create it, and then we make a new $arrCSVShareInfo with the new share name (the next share) when finished.
 
$counter = $null
$arrCSVShareInfo = @()
For($counter = 0;$counter -le $sharelist.length;$counter++) {
    If (($sharelist[$counter].name -eq $sharelist[$counter-1].name) -or ($counter -eq 0)) {
        $arrCSVShareInfo += $sharelist[$counter]
    }
 
    ElseIf ((($sharelist[$counter].name -ne $sharelist[$counter-1].name) -and ($counter -ne 0)) -or ($counter -eq $sharelist.length)) {
        $name = $sharelist[$counter-1].name
        $path = $sharelist[$counter-1].path
        $description = $sharelist[$counter-1].description
        write-host "Processing :" $arrCSVShareInfo[0].name
 
        # Pass each share through verification process, failed shares have error message stored in $err
        $blnErrorsDetected = VerifyAndFix-ShareInfo $Name $Path $arrCSVShareInfo -EV err -EA SilentlyContinue
 
        #Check if share exists, only want to create it if it does not exist
        $blnShareExists = $null
        $blnShareExists = Check-DoesShareExist $name
 
        #Only want to create it if there were no errors
        If ($blnErrorsDetected -eq $true) {
            trap {continue;}
            $ProblemShares.Add($name, $err)
        }
        ElseIf ($blnShareExists -eq $false) {
 
            #Create Security Objects
            $objWMI_SD = ([WMIClass] ("\\" + $FileServer + "\root\CIMv2:Win32_SecurityDescriptor")).CreateInstance()
            $objWMI_SD.DACL = @()
            $objWMI_EmptyACE = ([WMIClass] ("\\" + $FileServer + "\root\CIMv2:Win32_ACE")).CreateInstance()
            $objWMI_Trustee = ([WMIClass] ("\\" + $FileServer + "\root\CIMv2:Win32_Trustee")).CreateInstance()
 
            $arrCSVShareInfo | % {
            $objWMI_CompleteACE = (Add-PermissionsToACE $_ $objWMI_Trustee $objWMI_EmptyACE )
            $objWMI_SD.DACL += $objWMI_CompleteACE.PsObject.BaseObject
            }
 
            $blnShareCreated = Create-ShareFromCSVinfo $Name $Path $Description $objWMI_SD
            If ($blnShareCreated -eq $false) {
                $ProblemShares.Add($name, "Share Creation Failed")
            }
        }
        #Make a new array for the next share
        $arrCSVShareInfo = @()
        $arrCSVShareInfo += $sharelist[$counter]
    }
}
Write-Host "Import Complete" -ForegroundColor green
If ($problemShares.count -ge 1) {
    Write-Host "These Shares Failed to Import:"
    #Write the failed shares to the screen, complete with detailed error messages
    $ProblemShares
}
