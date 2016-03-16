Import-module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')

#Get SiteCode
$SiteCode = Get-PSDrive -PSProvider CMSITE
Set-location $SiteCode":"

#Refresh Schedule
$Schedule = New-CMSchedule –RecurInterval Days –RecurCount 1

#Create Defaut Folder 
$CollectionFolder = @{Name = "Windows Updates"; ObjectType = 5000; ParentContainerNodeId = 0}
Set-WmiInstance -Namespace "root\sms\site_$($SiteCode.Name)" -Class "SMS_ObjectContainerNode" -Arguments $CollectionFolder


#Create Default limiting collections
$LimitingCollection = "All Systems"

$FolderPath = $SiteCode.Name + ":\DeviceCollection\Windows Updates"



#Create Collection for Servers Manual Update

New-CMDeviceCollection -Name "Microsoft Updates - Servers - Manual" -Comment "Updates for Servers - Manual.  No Maintenance Window.  Deployments are only Available, not required." -LimitingCollectionName $LimitingCollection -RefreshSchedule $Schedule -RefreshType 2

Move-CMObject -FolderPath $FolderPath -InputObject (Get-CMDeviceCollection -Name "Microsoft Updates - Servers - Manual")

#Create Collection for Servers Prodcution Wave 1

New-CMDeviceCollection -Name "Microsoft Updates - Servers - Production Wave 1" -Comment "Updates for Servers - Production wave 1.  Maintenance Window Friday @ 11PM" -LimitingCollectionName $LimitingCollection -RefreshSchedule $Schedule -RefreshType 2

Add-CMUserCollectionExcludeMembershipRule -CollectionName "Microsoft Updates - Servers - Production Wave 1" -ExcludeCollectionName "Microsoft Updates - Servers - Manual" 

Move-CMObject -FolderPath $FolderPath -InputObject (Get-CMDeviceCollection -Name "Microsoft Updates - Servers - Production Wave 1")

$Schedule = New-CMSchedule -DurationCount 1 -DurationInterval Hours -WeekOrder 3 -DayOfWeek "Friday"  -Start ([Datetime]"23:00")
$Collection = Get-CMDeviceCollection -Name "Microsoft Updates - Servers - Production Wave 1"
New-CMMaintenanceWindow -CollectionID $Collection.CollectionID -Schedule $Schedule -Name "Microsoft Updates - Servers - Production Wave 1"


#Create Collection for Servers Prodcution Wave 2

New-CMDeviceCollection -Name "Microsoft Updates - Servers - Production Wave 2" -Comment "Updates for Servers - Production wave 1.  Maintenance Window Saturday @ 2AM" -LimitingCollectionName $LimitingCollection -RefreshSchedule $Schedule -RefreshType 2

Add-CMUserCollectionExcludeMembershipRule -CollectionName "Microsoft Updates - Servers - Production Wave 2" -ExcludeCollectionName "Microsoft Updates - Servers - Manual" 

$Wave2Query = @"
select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 5.2" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.0" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.1" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.2" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.3" or SMS_R_System.OperatingSystemNameandVersion like "Microsoft Windows NT%Server 6.4"
"@

Add-CMDeviceCollectionQueryMembershipRule -CollectionName "Microsoft Updates - Servers - Production Wave 2" -QueryExpression $Wave2Query  -RuleName "Microsoft Updates - Servers - Production Wave 2"
$Schedule = New-CMSchedule -DurationCount 1 -DurationInterval Hours -WeekOrder 3 -DayOfWeek "Saturday"  -Start ([Datetime]"2:00")
$Collection = Get-CMDeviceCollection -Name "Microsoft Updates - Servers - Production Wave 2"
New-CMMaintenanceWindow -CollectionID $Collection.CollectionID -Schedule $Schedule -Name "Microsoft Updates - Servers - Production Wave 2"

Move-CMObject -FolderPath $FolderPath -InputObject (Get-CMDeviceCollection -Name "Microsoft Updates - Servers - Production Wave 2")

