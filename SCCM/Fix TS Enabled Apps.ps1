<#
	.SYNOPSIS
	This script will iterate through all SCCM Applications, identify any applications that do not have the "Allow this application to be installed from the Install Application task sequence action without being deployed" checkbox checked, and then it will then "check" the box for each application.


#>

$AllApps = Get-CMApplication
$UnCheckedApps =  $AllApps | ?{! $([xml]$_.SDMPackageXML).AppMgmtDigest.Application.AutoInstall}

$UnCheckedApps | Format-Table LocalizedDisplayName

$UnCheckedApps | Foreach-Object {
	Set-CMApplication -AutoInstall $True -Name $_.LocalizedDisplayName -Verbose
}