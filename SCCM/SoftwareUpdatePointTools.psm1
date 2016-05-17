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
            Query = ""
        },
        @{
            Name = "TMicrosoft Updates - Desktop - Testing"; 
            Query = ""
        },
        @{
            Name = "TMicrosoft Updates - Desktop - Production"; 
            Query = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 5.1" or SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.1" or SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.3" or SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.4"'
            Exclude=@("TMicrosoft Updates - Desktop - Manual","TMicrosoft Updates - Desktop - Testing")
        },
        @{
            Name = "TMicrosoft Updates - Server - Manual"; 
            Query = ""
        },
        @{
            Name = "TMicrosoft Updates - Server - Testing"; 
            Query = ""
        },
        @{
            Name = "TMicrosoft Updates - Server - Production"; 
            Query = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 5.2" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.0" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.1" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.2" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.3" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.4"'
            Exclude=@("TMicrosoft Updates - Server - Manual","TMicrosoft Updates - Server - Testing")
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
        Move-CMObject -FolderPath $FolderPath -InputObject (Get-CMDeviceCollection -Name $Collection.Name)
    }
}