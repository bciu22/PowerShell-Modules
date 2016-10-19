<#
  .SYNOPSIS
    This script will replace O365 licenses
  
  .PARAMETER Commit
    False by default.  Setting this flag causes the script to make changes against the O365 environment.  Leaving this flag unset will cause the script to run in "read-only" mode, and no changes will be made.
  
  .PARAMETER OldLicense
    Specify the AccountSkuId to be replaced     
  .PARAMETER NewLicense
    Specify the enw AccountSkuId
  
  .PARAMETER DisabledPlans
    Specify an array of DisabledPlans
    
  .PARAMETER UserLimit
    If set to 0, operate on all users.  Else, limit O365 users to this value.
  
  .LINK
    https://support.office.com/en-us/article/Assign-or-unassign-licenses-for-Office-365-for-business-997596b5-4173-4627-b915-36abac6786dc
  
  .NOTES
    Authors: Charles Crossan

#>
[CmdletBinding()]
Param(
  [Parameter()]
  [Switch]$Commit=$False,
  [Parameter()]
  $OldLicense = "bucksiu:STANDARDWOFFPACK_FACULTY",
  [Parameter()]
  $NewLicense = "bucksiu:STANDARDWOFFPACK_IW_FACULTY",
  [Parameter()]
  $DisabledPlans = @("EXCHANGE_S_STANDARD"),
  [Parameter()]
  $UserLimit=0
)

$ExecutionStartTime = Get-Date
$LogName = "O365 License Replacement Script"
#Setup Logging
if(![System.Diagnostics.EventLog]::SourceExists($LogName))
{
  New-EventLog -LogName "Application" -Source $LogName
}
try
{
  . "$PSScriptRoot\config.ps1"
}
catch
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Error -EventID 126 -Message "Error loading config file.  Stopping execution.  Please ensure that config.ps1 is present in the same directory as the script, and that it is valid."
  Break
}

#Generate the PSCredential
If (!$userName -or !$Password)
{
  #no userName provided
  If(!$userName)
  {
    $Credentials = Get-Credential -Message "Please provide a valid MSOL login"
  }
  #username provided, no password
  Else
  {
    $Credentials = Get-Credential -UserName $UserName -Message "Please provide your MSOL login password"
  }
}
Else
{
  $secureString = ConvertTo-SecureString -String $password -AsPlainText -Force
  $Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $secureString
}

Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 102 -Message "Connecting to MsolService"
try
{
  Connect-MsolService -Credential $Credentials -ErrorAction Stop
}
catch
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Error -EventID 125 -Message "Error connecting to MSOL Service. $($_ | out-string)"
}


$NewLicensePlan = New-MsolLicenseOptions -AccountSkuId $NewLicense -DisabledPlans $DisabledPlans

Function Has-UserLicense
{
    param (
        $user,
        $AccountSkuIU
    )
    foreach ($license in $user.Licenses)
    {
        if ($license.AccountSkuId -eq $AccountSkuIU)
        {
           1
        }
    }
}

if($UserLimit -eq 0)
{
  $Users = Get-MSOLUser -All 
}
else {
   $Users = Get-MSOLUser -MaxResults $UserLimit
}

$UsersWithOldLicense = $users | ?{$(Has-UserLicense -user $_ -AccountSkuIU $OldLicense)}
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 127 -Message "Found $($UsersWithOldLicense.count) users with old license $($OldLicense)"


Foreach ( $User in $UsersWithOldLicense )
{
    
    if ($Commit)
    {
      Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 128 -Message  "Updating User License for $($User.UserPrincipalName) from $OldLicense to $NewLicense"
      $User | Set-MsolUserLicense -AddLicenses $NewLicense -LicenseOptions $NewLicensePlan  -RemoveLicenses $OldLicense -ErrorAction "Stop"
    }
    else {
      Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 129 -Message  "WhatIf: Updating User License for $($User.UserPrincipalName) from $OldLicense to $NewLicense"
    }    

}


