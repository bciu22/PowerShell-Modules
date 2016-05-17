Create-UpdatingDeviceCollections
{

    $SiteCode = Get-PSDrive -PSProvider CMSITE
    Set-location $SiteCode":"

    #Refresh Schedule
    $Schedule = New-CMSchedule –RecurInterval Days –RecurCount 1
    
    #Create Defaut Folder 
    New-Item -Path  $SiteCode":\DeviceCollection\" -Name "Windows Updates TEST" -ErrorAction SilentlyContinue

    #Create Default limiting collections
    $LimitingCollection = "All Systems"

    $Collections = @(
        @{
            Name = "TMicrosoft Updates - Desktop - Manual"; 
        },
        @{
            Name = "TMicrosoft Updates - Desktop - Testing"; 
            MaintenanceWindowSchedule=New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "16:00" -End "19:00"
        },
        @{
            Name = "TMicrosoft Updates - Desktop - Production"; 
            Query = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 5.1" or SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.1" or SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.3" or SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.4"'
            Exclude=@("TMicrosoft Updates - Desktop - Manual","TMicrosoft Updates - Desktop - Testing")
            MaintenanceWindowSchedule=New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "16:00" -End "19:00"
        },
        @{
            Name = "TMicrosoft Updates - Server - Manual"; 
        },
        @{
            Name = "TMicrosoft Updates - Server - Testing"; 
            MaintenanceWindowSchedule=New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "16:00" -End "19:00"
        },
        @{
            Name = "TMicrosoft Updates - Server - Production Wave 2"; 
            MaintenanceWindowSchedule=New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "03:00" -End "05:00"
        },
        @{
            Name = "TMicrosoft Updates - Server - Production Wave 1"; 
            Query = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 5.2" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.0" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.1" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.2" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.3" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.4"'
            Exclude=@("TMicrosoft Updates - Server - Manual","TMicrosoft Updates - Server - Testing", "TMicrosoft Updates - Server - Production Wave 2")
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