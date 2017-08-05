
$originalDNS = $env:USERDOMAIN

function processDomain ($domainPassed)
{
    $domainResults = get-addomain -Server $domainPassed | select -Property Name, DomainMode, DNSRoot, ParentDomain, RIDMaster, PDCEmulator, InfrastructureMaster  
    return $domainResults
}

function processControllers($domainPassed)
{
   # Get-ADDomainController -domainName $domainPassed -Discover | sort -Descending Site | Get-ADDomainController -domainname $domainPassed | select -Property hostname, IPv4Address, Site, isGlobalCatalog, isReadOnly, OperatingSystem, Enabled | ft -Force
    $domainPassed | % { Get-addomaincontroller -Filter * -server $_ } | sort -Descending Site | select -Property hostname, IPv4Address, Site, isGlobalCatalog, isReadOnly, OperatingSystem, Enabled | ft -Force
}

function processTrusts ()
{
    $trustResults = get-adtrust -filter * | where foresttransitive -eq $True
    return $trustResults
}

function getForest ($forestPassed)
{
    $forestInfo = get-adforest -server $forestPassed | select -property RootDomain, SchemaMaster, DomainNamingMaster, ForestMode, GlobalCatalogs, domains, Sites
    return $forestInfo
}

function processForest($forestName)
{
    $forest = getForest $forestName
    Write-Output "##### BEGIN Forest: $($forest.RootDomain) #####"
    $forest

    foreach ($indDomain in (($forest.domains) -split ","))
    {
        Write-Output "Domain: $indDomain"
        processDomain $indDomain

        Write-Output "Trusts for $indDomain"
        Get-ADTrust -filter * -server $indDomain | where foresttransitive -eq $True | select  Name, Source, Target, Direction, ForestTransitive | ft

        Write-Output "Domain Controllers for $indDomain"
        processControllers $indDomain
    }

    Write-Output "##### END Forest: $($forest.RootDomain) #####"
    Write-Output ""
}


processForest $originalDNS

$allTrusts = processTrusts

foreach ($indTrust in ($allTrusts.Name))
{
    processForest $indTrust
}
