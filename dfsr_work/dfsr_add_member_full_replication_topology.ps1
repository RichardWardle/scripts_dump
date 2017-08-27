 #This script will bring in a new server into a replication group
#It should only be used on a FULL MESH topology, there will be
#another script for hub and spoke. It should also only be used 
#when it will participate in all replication folders

Import-Module DFSR

　
　
$groupname = "HR" #this is the RG name
$source_sync = "member1" #this is the source server which we will try pull our data from
$new_server = "member6.example.com" #this is the new server we are bringing in
$content_path = "C:\data\"
$dfsr_path = "C:\dfsr_storage\"

#try
#{
    #add our selves into the replication group
    Add-DfsrMember -GroupName $groupname -ComputerName $new_server

    #build our selves into the full topology by adding relevant connections
    $member_connections = Get-DfsrConnection -GroupName $groupname -SourceComputerName $source_sync
    
    foreach ($indConn in $member_connections)
    {
        Add-DfsrConnection -GroupName $groupname -SourceComputerName $new_server -DestinationComputerName $indConn.destinationcomputername -DomainName $indConn.domainname
        #Add-DfsrConnection -GroupName $groupname -SourceComputerName $indConn.destinationcomputername -DestinationComputerName $new_server -DomainName $indConn.domainname  

        #gets the current schedule between the two points
        $member_schedule_connection = Get-DfsrConnectionSchedule -GroupName $groupname -SourceComputerName $indConn.sourcecomputername -DestinationComputerName $indConn.destinationcomputername
        
        #creates that same connection schedule with the new servers if it is a custom schedule
        if (-not ($member_schedule_connection.BandwidthDetail -eq "Using the replication group's schedule."))
        {
            #Set-DfsrConnectionSchedule -GroupName $groupname -SourceComputerName $new_server -DestinationComputerName $indconn.destinationcomputername -UseUTC $member_schedule_connection.UseUTC -BandwidthDetail $member_schedule_connection.BandwidthDetail
        }
    }

    #add our selves to all the replicated folders
    $replicated_folders = Get-DfsReplicatedFolder -GroupName $groupname | Get-DfsrMembership -ComputerName $source_sync
    foreach ($indFolder in $replicated_folders)
    {
        $full_content_path = $content_path + "" + $indFolder.foldername
        $dfsr_full_path = $dfsr_path + "" + $indFolder.foldername
        if (-not (Test-Path $full_content_path)) { mkdir $full_content_path }
        if( -not (test-path $dfsr_full_path\DfsrPrivate)) {New-Item $dfsr_full_path\DfsrPrivate -ItemType Directory | %{$_.Attributes = "hidden"}}
        if( -not (test-path $dfsr_full_path\DfsrPrivate\ConflictAndDeleted)) {mkdir $dfsr_full_path\DfsrPrivate\ConflictAndDeleted}
        if( -not (test-path $dfsr_full_path\DfsrPrivate\ConflictAndDeleted)) {mkdir $dfsr_full_path\DfsrPrivate\Staging}

        Set-DfsrMembership -computername $new_server -GroupName $groupname -FolderName $indFolder.FolderName -ContentPath $full_content_path -StagingPath "$dfsr_full_path\DfsrPrivate\staging" -force
    }
#}
#catch
#{
#    Write-Output "I could not add $new_server to the replication group: $groupname"
#    Exit 2
#}  #This script will bring in a new server into a replication group

#It should only be used on a FULL MESH topology, there will be

#another script for hub and spoke. It should also only be used 

#when it will participate in all replication folders


Import-Module DFSR


　

　

$groupname = "HR" #this is the RG name

$source_sync = "member1" #this is the source server which we will try pull our data from

$new_server = "member6.example.com" #this is the new server we are bringing in

$content_path = "C:\data\"

$dfsr_path = "C:\dfsr_storage\"


#try

#{

    #add our selves into the replication group

    Add-DfsrMember -GroupName $groupname -ComputerName $new_server


    #build our selves into the full topology by adding relevant connections

    $member_connections = Get-DfsrConnection -GroupName $groupname -SourceComputerName $source_sync

    

    foreach ($indConn in $member_connections)

    {

        Add-DfsrConnection -GroupName $groupname -SourceComputerName $new_server -DestinationComputerName $indConn.destinationcomputername -DomainName $indConn.domainname

        #Add-DfsrConnection -GroupName $groupname -SourceComputerName $indConn.destinationcomputername -DestinationComputerName $new_server -DomainName $indConn.domainname  


        #gets the current schedule between the two points

        $member_schedule_connection = Get-DfsrConnectionSchedule -GroupName $groupname -SourceComputerName $indConn.sourcecomputername -DestinationComputerName $indConn.destinationcomputername

        

        #creates that same connection schedule with the new servers if it is a custom schedule

        if (-not ($member_schedule_connection.BandwidthDetail -eq "Using the replication group's schedule."))

        {

            #Set-DfsrConnectionSchedule -GroupName $groupname -SourceComputerName $new_server -DestinationComputerName $indconn.destinationcomputername -UseUTC $member_schedule_connection.UseUTC -BandwidthDetail $member_schedule_connection.BandwidthDetail

        }

    }


    #add our selves to all the replicated folders

    $replicated_folders = Get-DfsReplicatedFolder -GroupName $groupname | Get-DfsrMembership -ComputerName $source_sync

    foreach ($indFolder in $replicated_folders)

    {

        $full_content_path = $content_path + "" + $indFolder.foldername

        $dfsr_full_path = $dfsr_path + "" + $indFolder.foldername

        if (-not (Test-Path $full_content_path)) { mkdir $full_content_path }

        if( -not (test-path $dfsr_full_path\DfsrPrivate)) {New-Item $dfsr_full_path\DfsrPrivate -ItemType Directory | %{$_.Attributes = "hidden"}}

        if( -not (test-path $dfsr_full_path\DfsrPrivate\ConflictAndDeleted)) {mkdir $dfsr_full_path\DfsrPrivate\ConflictAndDeleted}

        if( -not (test-path $dfsr_full_path\DfsrPrivate\ConflictAndDeleted)) {mkdir $dfsr_full_path\DfsrPrivate\Staging}


        Set-DfsrMembership -computername $new_server -GroupName $groupname -FolderName $indFolder.FolderName -ContentPath $full_content_path -StagingPath "$dfsr_full_path\DfsrPrivate\staging" -force

    }

#}

#catch

#{

#    Write-Output "I could not add $new_server to the replication group: $groupname"

#    Exit 2

#} 
