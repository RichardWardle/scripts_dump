Param(
  [Parameter(Mandatory=$false)]
  [ValidateScript({ try {$_ -match [bool]$_} catch { Write-Output "$_ is not a boolean value"; Exit 3} })]
  [bool]$checkonly = $True
)

#Function used for getting the results from that path, first one is for path of variable and the second is for the attributes in that folder
function getRegistryResults($regPathFunc, $regValFunc)
{
    $temp = Get-ItemProperty -path $regPathFunc | select ($regValFunc)
    return $temp
}

#function used to set or create correct value, first is the path, second is the Name of the registry entry, third is the type e.g. DWORD and fourth is your actual value for the name
function newRegistryResults($newPathFunc, $newValName, $newType, $newValValue)
{
    New-ItemProperty -path $newPathFunc -name $newValName -PropertyType $newType -Value $newValValue -Force | out-null
}

function createcheckRegistryFolder($newRegFolder)
{
    if(!(Test-Path $newRegFolder)) { New-Item -path $newRegFolder -Force | out-null}
}

#Function that is passed the variables we want, path of the registry, the key name, key value we expect, the type of value it is e.g DWORD and the message of the check
function checkRegistry($checkValueRegPath, $checkValueRegName, $checkValueRegValue, $checkValueRegType, $checkValueRegMessage)
{
    createcheckRegistryFolder $checkValueRegPath
    $results = getRegistryResults $checkValueRegPath $checkValueRegName

    if ($results.$checkValueRegName -ne $checkValueRegValue)
    {
        if ($checkonly) { $colorOutput = "red" }
        else
        { 
            newRegistryResults $checkValueRegPath $checkValueRegName $checkValueRegType $checkValueRegValue
            $colorOutput = "Magenta"
        }
    }
    else
    {
        $colorOutput = "green"
    }
    Write-Host "$checkValueRegMessage, $colorOutput" -ForegroundColor "$colorOutput"
}

#set default color for heading
$colorOutput = "yellow"

Write-host ""
Write-host "###################################################################" -ForegroundColor $colorOutput
Write-host "Auto configuration Setting for ensuring server compliance is met!!!" -ForegroundColor $colorOutput
Write-host "Green setting correct"                                               -ForegroundColor "green"
Write-host "Magenta setting was wrong and is now correct"                        -ForegroundColor "Magenta"
Write-host "Red means incorrect (used with -checkonly true)"                     -ForegroundColor "red"
Write-host "###################################################################" -ForegroundColor $colorOutput
Write-host ""

#Default Types in registry, you can add more for ones i have not added
$typeDWORD = "DWORD"
$typeString = "String"

###### BEGIN: This section checks the Default login configuration ######
checkRegistry "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon" "AutoAdminLogon" "1" $typeDWORD "Auto Admin Login Setting"
checkRegistry "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon" "DefaultUserName" "Username" $typeString "Auto Admin Username Setting"
checkRegistry "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon" "DefaultPassword" "Password" $typeString "Auto Admin Password Setting"
###### END: This section ends the Default login configuration ######

### You can add your registry changes here ###
