Create-UpdatingDeviceCollections
{

    $SiteCode = Get-PSDrive -PSProvider CMSITE
    Set-location $SiteCode":"

    #Refresh Schedule
    $Schedule = New-CMSchedule –RecurInterval Days –RecurCount 1
    
    #Create Defaut Folder 
    New-Item -Path  $SiteCode":\DeviceCollection\" -Name "Windows Updates" -ErrorAction SilentlyContinue
    $FolderPath = "$($SiteCode):\DeviceCollection\Windows Updates"

    #Create Default limiting collections
    $LimitingCollection = "All Systems"

    $Collections = @(
        @{
            Name = "Microsoft Updates - Desktop - Manual"; 
        },
        @{
            Name = "Microsoft Updates - Desktop - Testing"; 
            MaintenanceWindowSchedule=New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "16:00" -End "19:00"
        },
        @{
            Name = "Microsoft Updates - Desktop - Production"; 
            Query = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 5.1" or SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.1" or SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.3" or SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.4"'
            Exclude=@("Microsoft Updates - Desktop - Manual","Microsoft Updates - Desktop - Testing")
            MaintenanceWindowSchedule=New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "16:00" -End "19:00"
        },
        @{
            Name = "Microsoft Updates - Server - Manual"; 
        },
        @{
            Name = "Microsoft Updates - Server - Testing"; 
            MaintenanceWindowSchedule=New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "16:00" -End "19:00"
        },
        @{
            Name = "Microsoft Updates - Server - Production Wave 2"; 
            MaintenanceWindowSchedule=New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "03:00" -End "05:00"
        },
        @{
            Name = "Microsoft Updates - Server - Production Wave 1"; 
            Query = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 5.2" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.0" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.1" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.2" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.3" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.4"'
            Exclude=@("Microsoft Updates - Server - Manual","Microsoft Updates - Server - Testing", "Microsoft Updates - Server - Production Wave 2")
            MaintenanceWindowSchedule=New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "23:00" -End "02:00"
        }        
     )

    Foreach($Collection in $Collections)
    {
        New-CMDeviceCollection -Name $Collection.Name  -LimitingCollectionName $LimitingCollection -RefreshSchedule $Schedule -RefreshType 2 | Out-Null
        if($collection.Query)
        {
            Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -QueryExpression $Collection.Query -RuleName $Collection.Name
        }
        if($Collection.Exclude)
        {
            ForEach($excludeName in $Collection.exclude)
            {
                Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $Collection.Name -ExcludeCollectionName $excludeName
            }
        }
        if($Collection.MaintenanceWindowSchedule)
        {
            New-CMMaintenanceWindow -CollectionName  $Collection.Name -Schedule  $Collection.MaintenanceWindowSchedule -Name "$($Collection.Name) Maintenance Window"
        }
        Move-CMObject -FolderPath $FolderPath -InputObject (Get-CMDeviceCollection -Name $Collection.Name)
    }
}

Function Create-SUGDeployments
{

#$DeviceCollections = @("Microsoft Updates - Desktop - Manual","Microsoft Updates - Desktop - Production","Microsoft Updates - Desktop - Testing",`
#"Microsoft Updates - Server - Manual","Microsoft Updates - Server - Production","Microsoft Updates - Server - Testing")

$DeviceCollections = @("Microsoft Updates - Desktop - Testing")

$SUGs = @("Windows Updates - 2016 - 1", "Windows Updates - 2014", "Windows Updates - 2015", "Windows Updates - 2013 and Older")

Foreach($sugName in $SUGS)
{
    $SUG = Get-CMSoftwareUpdateGroup -Name $sugName
    Write-Host "Processing SUG: $($SUG.LocalizedDisplayName)"
    Foreach($DeviceCollectionName in $DeviceCollections)
    {
        $DeviceCollection = Get-CMDeviceCollection -Name $DeviceCollectionName
        Write-Host "Processing Device Collection: $($DeviceCollection.NAme)"
        if($DeviceCollection.Name -like "*Manual*")
        {
            Write-Host "Creating Available Manual Deployment of $($SUG.LocalizedDisplayName) for $($DeviceCollection.Name)"
            Start-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $SUG.LocalizedDisplayName`
            -CollectionName $DeviceCollection.Name `
            -DeploymentName "$($DeviceCollection.Name) - $($SUG.LocalizedDisplayName)" `
            -DeploymentType Available `
            -SendWakeUpPacket $False `
            -VerbosityLevel AllMessages `
            -TimeBasedOn UTC `
            -UserNotification DisplaySoftwareCenterOnly `
            -SoftwareInstallation $True `
            -AllowRestart $True `
            -RestartServer $False `
            -RestartWorkstation $False `
            -PersistOnWriteFilterDevice $False `
            -GenerateSuccessAlert $False `
            -ProtectedType RemoteDistributionPoint `
            -UnprotectedType NoInstall `
            -UseBranchCache $False `
            -DownloadFromMicrosoftUpdate $True `
            -AllowUseMeteredNetwork $True `
            -AcceptEULA
        }
        elseif($DeviceCollection.Name -like "*Testing*")
        {
            Write-Host "Creating Required Testing Deployment of $($SUG.LocalizedDisplayName) for $($DeviceCollection.Name)"
            Start-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $SUG.LocalizedDisplayName`
            -CollectionName $DeviceCollection.Name `
            -DeploymentName "$($DeviceCollection.Name) - $($SUG.LocalizedDisplayName)" `
            -DeploymentType Required `
            -SendWakeUpPacket $False `
            -VerbosityLevel AllMessages `
            -TimeBasedOn UTC `
            -UserNotification DisplaySoftwareCenterOnly `
            -SoftwareInstallation $True `
            -AllowRestart $True `
            -RestartServer $True `
            -RestartWorkstation $True `
            -PersistOnWriteFilterDevice $False `
            -GenerateSuccessAlert $False `
            -ProtectedType RemoteDistributionPoint `
            -UnprotectedType NoInstall `
            -UseBranchCache $False `
            -DownloadFromMicrosoftUpdate $True `
            -AllowUseMeteredNetwork $True `
            -AcceptEULA
        }
        elseif($DeviceCollection.Name -like "*Production*")
        {
            Write-Host "Creating Required Production Deployment of $($SUG.LocalizedDisplayName) for $($DeviceCollection.Name)"
            Start-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $SUG.LocalizedDisplayName`
            -CollectionName $DeviceCollection.Name `
            -DeploymentName "$($DeviceCollection.Name) - $($SUG.LocalizedDisplayName)" `
            -DeploymentType Required `
            -SendWakeUpPacket $False `
            -VerbosityLevel AllMessages `
            -TimeBasedOn UTC `
            -UserNotification DisplaySoftwareCenterOnly `
            -SoftwareInstallation $True `
            -AllowRestart $True `
            -RestartServer $True `
            -RestartWorkstation $True `
            -PersistOnWriteFilterDevice $False `
            -GenerateSuccessAlert $False `
            -ProtectedType RemoteDistributionPoint `
            -UnprotectedType NoInstall `
            -UseBranchCache $False `
            -DownloadFromMicrosoftUpdate $True `
            -AllowUseMeteredNetwork $True `
            -AcceptEULA
        }

    }
}


}