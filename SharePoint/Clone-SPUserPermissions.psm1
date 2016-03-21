Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue
 
#Function to copy user permissions
Function Copy-UserPermissions($SourceUserID, $TargetUserID, [Microsoft.SharePoint.SPSecurableObject]$Object)
{
	Write-Host "Object Type: $($SourceUserID), $($TargetUserID) $($Object.GetType().FullName)"
	#Determine the given Object type and Get URL of it
	Switch($Object.GetType().FullName)
	{
		"Microsoft.SharePoint.SPWeb"  
		{ 
			$ObjectType = "Site"
			$ObjectURL = $Object.URL
			$web = $Object 
		}
		"Microsoft.SharePoint.SPListItem"
		{
			if($Object.Folder -ne $null)
			{
				$ObjectType = "Folder"
				$ObjectURL = "$($Object.Web.Url)/$($Object.Url)"
				$web = $Object.Web
			}
			else
			{
				$ObjectType = "List Item"
				$ObjectURL = "$($Object.Web.Url)/$($Object.Url)"
				$web = $Object.Web
			}
		}
		#Microsoft.SharePoint.SPList, Microsoft.SharePoint.SPDocumentLibrary, Microsoft.SharePoint.SPPictureLibrary,etc
		default 
		{
			$ObjectType = "List/Library"
			$ObjectURL = "$($Object.ParentWeb.Url)/$($Object.RootFolder.URL)"
			$web = $Object.ParentWeb 
		}
	}
 
	#Get Source and Target Users
	$SourceUser = $Web.EnsureUser($SourceUserID)
	$TargetUser = $Web.EnsureUser($TargetUserID)

	#Get Permissions of the Source user on given object - Such as: Web, List, Folder, ListItem
	$SourcePermissions = $Object.GetUserEffectivePermissionInfo($SourceUser)
	 
	#Iterate through each permission and get the details
	foreach($SourceRoleAssignment in $SourcePermissions.RoleAssignments)
	{
		#Get all permission levels assigned to User account directly or via SharePOint Group
		$SourceUserPermissions=@()
		foreach ($SourceRoleDefinition in $SourceRoleAssignment.RoleDefinitionBindings)
		{
			#Exclude "Limited Accesses"
			if($SourceRoleDefinition.Name -ne "Limited Access")
			{
				  $SourceUserPermissions += $SourceRoleDefinition.Name
			}
		}

		#Check Source Permissions granted directly or through SharePoint Group
		if($SourceUserPermissions)
		{
			if($SourceRoleAssignment.Member -is [Microsoft.SharePoint.SPGroup])  
			{
				$SourcePermissionType = "'Member of SharePoint Group - " + $SourceRoleAssignment.Member.Name +"'"
				 
				#Add Target User to the Source User's Group
				#Get the Group
				$Group = [Microsoft.SharePoint.SPGroup]$SourceRoleAssignment.Member
				  
				#Check if user is already member of the group - If not, Add to group
				if( ($Group.Users | where {$_.UserLogin -eq $TargetUserID}) -eq $null )
				{
				  #Add User to Group
				  $Group.AddUser($TargetUser)
				  #Write-Host Added to Group: $Group.Name
				}    
			}
			else
			{
				$SourcePermissionType = "Direct Permission"
				#Add Each Direct permission (such as "Full Control", "Contribute") to Target User
				foreach($NewRoleDefinition in $SourceUserPermissions)
				{   
					#Role assignment is a linkage between User object and Role Definition
					$NewRoleAssignment = New-Object Microsoft.SharePoint.SPRoleAssignment($TargetUser)
					$NewRoleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions[$NewRoleDefinition])
					  
					$object.RoleAssignments.Add($NewRoleAssignment)
					$object.Update()    
				}     
			}
			$SourceUserPermissions = $SourceUserPermissions -join ";" 
			Write-Host "***$($ObjectType) Permissions Copied: $($SourceUserPermissions) at $($ObjectURL) via $($SourcePermissionType)***"
		}  
	}
}
 
Function Clone-SPUser
{
param(
$SourceUserID, 
$TargetUserID, 
$WebAppURL
)
<#
.SYNOPSIS
	Iterates through all SPSecurableObject items in a given web application, and copies any permissions found for the 
	Source user to the Target user.
	
.EXAMPLE
	Clone-SPUser -SourceUserID "CONTOSO\CBrown" -TargetUserID "CONTOSO\BBarker" -WebAppURL "https://portal.contoso.com"

#>
	###Check Whether the Source Users is a Farm Administrator ###
	Write-host "Scanning Farm Administrators Group..."
	#Get the SharePoint Central Administration site
	$AdminWebApp = Get-SPwebapplication -includecentraladministration | where {$_.IsAdministrationWebApplication}
	$AdminSite = Get-SPWeb $AdminWebApp.Url
	$AdminGroupName = $AdminSite.AssociatedOwnerGroup
	$FarmAdminGroup = $AdminSite.SiteGroups[$AdminGroupName]
  
	#enumerate in farm adminidtrators groups
	foreach ($user in $FarmAdminGroup.users)
	{
		if($User.LoginName.Endswith($SourceUserID,1)) #1 to Ignore Case
		{
			#Add the target user to Farm Administrator Group
			$FarmAdminGroup.AddUser($TargetUserID,"",$TargetUserID , "")
			Write-Host "***Added to Farm Administrators Group!***"
		}    
    }
 
	### Check Web Application User Policies ###
	Write-host "Scanning Web Application Policies..."
	$WebApp = Get-SPWebApplication $WebAppURL  
  
	foreach ($Policy in $WebApp.Policies)
	{
		#Check if the search users is member of the group
		if($Policy.UserName.EndsWith($SourceUserID,1))
		{
			#Write-Host $Policy.UserName
			$PolicyRoles=@()
			foreach($Role in $Policy.PolicyRoleBindings)
			{
				$PolicyRoles+= $Role
			}
		}
	}
	#Add Each Policy found
	if($PolicyRoles)
	{
		$WebAppPolicy = $WebApp.Policies.Add($TargetUserID, $TargetUserID)
		foreach($Policy in $PolicyRoles)
		{
			$WebAppPolicy.PolicyRoleBindings.Add($Policy)
		}
		$WebApp.Update()
		Write-host "***Added to Web application Policies!***"
	}

	### Drill down to Site Collections, Webs, Lists & Libraries, Folders and List items ###
	#Get all Site collections of given web app
	$SiteCollections = Get-SPSite -WebApplication $WebAppURL -Limit All
 
	#Convert UserID Into Claims format - If WebApp is claims based! Domain\User to i:0#.w|Domain\User
    if( (Get-SPWebApplication $WebAppURL).UseClaimsAuthentication)
    {
        $SourceUserID = (New-SPClaimsPrincipal -identity $SourceUserID -identitytype 1).ToEncodedString()
		$TargetUserID = (New-SPClaimsPrincipal -identity $TargetUserID -identitytype 1).ToEncodedString()
    }
  
	#Loop through all site collections
    foreach($Site in $SiteCollections)
    {
		#Prepare the Target user
		$TargetUser = $Site.RootWeb.EnsureUser($TargetUserID)
		Write-host "Scanning Site Collection Administrators Group for:" $site.Url
		###Check Whether the User is a Site Collection Administrator
		foreach($SiteCollAdmin in $Site.RootWeb.SiteAdministrators)
		{
			if($SiteCollAdmin.LoginName.EndsWith($SourceUserID,1))
			{
				#Make the user as Site collection Admin
				$TargetUser.IsSiteAdmin = $true
				$TargetUser.Update()
				Write-host "***Added to Site Collection Admin Group***"
			}    
		}
		#Get all webs
		$WebsCollection = $Site.AllWebs
		#Loop throuh each Site (web)
		foreach($Web in $WebsCollection)
		{
			if($Web.HasUniqueRoleAssignments -eq $True)
			{
				Write-host "Scanning Site:" $Web.Url

				#Call the function to Copy Permissions to TargetUser
				Copy-UserPermissions $SourceUserID $TargetUserID $Web   
			}
		 
			#Check Lists with Unique Permissions
			Write-host "Scanning Lists on $($web.url)..."
			foreach($List in $web.Lists)
			{
				if($List.HasUniqueRoleAssignments -eq $True -and ($List.Hidden -eq $false))
				{
					Write-Host "List: $($List)"
					#Call the function to Copy Permissions to TargetUser
					Copy-UserPermissions $SourceUserID $TargetUserID $List
				}
			 
				#Check Folders with Unique Permissions
				$UniqueFolders = $List.Folders | where { $_.HasUniqueRoleAssignments -eq $True }                   
				#Get Folder permissions
				if($UniqueFolders)
				{
					foreach($folder in $UniqueFolders)
					{
						
						#Call the function to Copy Permissions to TargetUser
						Copy-UserPermissions $SourceUserID $TargetUserID $folder     
					}
				}
			 
				#Check List Items with Unique Permissions
				$UniqueItems = $List.Items | where { $_.HasUniqueRoleAssignments -eq $True }
				#Get Item level permissions
				if($UniqueItems)
				{
					foreach($item in $UniqueItems)
					{
						Write-Host "Item: $($Item)"
						#Call the function to Copy Permissions to TargetUser
						Copy-UserPermissions $SourceUserID $TargetUserID $Item 
					}
				}
			}
		}
	}
 Write-Host "Permission are copied successfully!"
  
}
