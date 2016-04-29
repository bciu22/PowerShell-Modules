<#
  .SYNOPSIS
    This script will update O365 licenses and usage locations for students and teachers
  
  .DESCRIPTION
    This connects to O365 through parameters defined in config.ps1 located in the same directory.  It evaluates O365 licenses and usage locations for two license types correlated to the values defined in config.ps1.
  
  .PARAMETER Commit
    False by default.  Setting this flag causes the script to make changes against the O365 environment.  Leaving this flag unset will cause the script to run in "read-only" mode, and no changes will be made.
  
  .PARAMETER EmailLevel
    Specify the circumstances under which this script will send email messages.  On "Error" by default, so email will only be sent if the script encounters an error.  "Verbose" will always send an email upon completion of a run.  "None" will never send an email.
    
  .LINK
    https://support.office.com/en-us/article/Assign-or-unassign-licenses-for-Office-365-for-business-997596b5-4173-4627-b915-36abac6786dc
  
  .NOTES
    Authors: Charles Crossan, Dan Lezoche

#>
[CmdletBinding()]
Param(
  [Parameter()]
  [Switch]$Commit=$False,
  [Parameter()]
  [ValidateSet('Error','Verbose','None')]
  $EmailLevel="Error"
)
$LogName = "O365 License Assignment Script"
#Setup Logging
if(![System.Diagnostics.EventLog]::SourceExists($LogName))
{
  New-EventLog -LogName "Application" -Source $LogName
}
#Import Configuration Parameters
try
{
  . "$PSScriptRoot\config.ps1"
}
catch
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Error -EventID 126 -Message "Error loading config file.  Stopping execution.  Please ensure that config.ps1 is present in the same directory as the script, and that it is valid."
  Break
}
#Script Defaults
#create emtpy arrays for staff/students
$Faculty = @()
$Students = @()

#Configure services to be applied
$FacultyPlanService = New-MsolLicenseOptions -AccountSkuId $FacultyLicense -DisabledPlans $DisabledPlans
$StudentPlanService = New-MsolLicenseOptions -AccountSkuId $StudentLicense -DisabledPlans $DisabledPlans




#Setup Email Destination for Reporting
$Now = Get-Date
$mailSubject = $cn + ": O365 License Provisioning " + $Now
$mailBody = "$cn" + " $Now " + "`r`n`r`n"

#Log all parameters
$LogLine = @"
DisabledPlans:  $DisabledPlans 
StudentOU: $StudentOU
UsageLocation: $UsageLocation
FacultyLicense:  $FacultyLicense
StudentLicense: $StudentLicense
Commit: $Commit
EmailLevel: $EmailLevel
"@
    
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 100 -Message $LogLine

Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 101 -Message "Importing MSonline module"
Import-Module MSOnline
 
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
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 103 -Message "Searching for all unlicensed accounts"
#Discover all unlicensed accounts
$Users = Get-MSOLUser -All 
$Unlicensed = $Users | Where-Object{$_.IsLicensed -ne $True}
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 104 -Message "Unlicensed accounts found: $($Unlicensed.Count)"

#Normalize Student OU
If(!$StudentOU.StartsWith("*"))
{
  $StudentOU = "*" + $StudentOU
}

Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 105 -Message "Analyzing accounts for Student/Facility licensing"
#Determine students/faculty based on UPN and AD OU
ForEach($User in $Unlicensed)
{
  #Get the AD Object based on UPN, which MSonline 
  $x = Get-ADUser -Filter {UserPrincipalName -eq $User.UserPrincipalName}
  #Determine if the account lives in a student OU, otherwise it's staff
  If($x.DistinguishedName -ilike $StudentOU)
  {
    $Students += $x.UserPrincipalName
  }
  Else
  {
    $Faculty += $x.UserPrincipalName
  }
}
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 106 -Message "Unlicensed Students: $($Students.Count)"
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 107 -Message "Unlicensed Facility: $($Faculty.Count)"

#Resolve UsageLocation if incorrect/unassigned
$NonUSUsageLocation = $Users | Where-Object{$_.UsageLocation -ne "US"}
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 108 -Message "UsageLocation Updates: $($NonUSUsageLocation.Count)"
If ($NonUSUsageLocation.count -gt 0)
{
  If($Commit)
  {
    $NonUSUsageLocation | ForEach-Object {
      Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 109 -Message "Setting UsageLocation to US for: $($_.UserPrincipalName)"
      $_ | Set-MsolUser -UsageLocation "US"
    }
  }
  Else
  {
    Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 110 -Message "WhatIf: UsageLocation updates skipped by configuration"
  }
}
Else
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 111 -Message "No UsageLocation updates required, skipping"
}

#Assign license to all student accounts
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 112 -Message "Assigning license to all student accounts"
If ($Students.count -gt 0)
{
  ForEach($student in $Students)
  {
    #Apply licensing
    If($Commit)
    {
      Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 113 -Message "Assigning license: $StudentLicense to $student"
      Try
      {
        Set-MsolUserLicense -UserPrincipalName $student -AddLicenses $StudentLicense -LicenseOptions $StudentPlanService -ErrorAction "Stop"
      }
      Catch
      {
        Write-EventLog -LogName "Application" -Source $LogName -EntryType Error -EventID 114 -Message "Assign License Failed $($_ | out-string)"
      }
    }
    Else
    {
      Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 115 -Message "WhatIf: Assigning license: $StudentLicense to $student"
    }   
  }
}
Else
{
     Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 116 -Message "No Student licenses necessary, skipping"
}

#Assign license to all faculty accounts
 Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 117 -Message "Assigning license to all faculty accounts"
If ($Faculty.count -gt 0)
{
  ForEach($staff in $Faculty)
  {
    #Apply licensing
    If($Commit)
    {
      Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 118 -Message "Assigning license: $FacultyLicense to $staff"
      Try
      {
        Set-MsolUserLicense -UserPrincipalName $staff -AddLicenses $FacultyLicense -LicenseOptions $FacultyPlanService -ErrorAction "Stop"
      }
      Catch
      {
        Write-EventLog -LogName "Application" -Source $LogName -EntryType Error -EventID 119 -Message "Assign License Failed $($_ | out-string)"
      }
    }
    Else
    {
      Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 120 -Message"WhatIf: Assigning license: $FacultyLicense to $staff"
    }   
  }
}
Else
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 121 -Message "No Faculty licenses necessary, skipping"
}

#Get the Events from the Error Log
$Events = Get-EventLog -LogName "Application" -Source $LogName -After $(Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-1)
#Count the errors
$ErrorCount =  $Events | ?{$_.EntryType -eq "Error" }  | Measure-Object | Select-Object -ExpandProperty Count

If($EmailLevel -eq "Error")  #If there were errors, and the parameters indicate to email on errors, set sendMail flag
{
  if($ErrorCount -gt 0)
  {
    Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 122 -Message "Execution Finished.  Errors Detected. Sending Events Email"
    $sendMail = $true
  }
  else
  {
    Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 125 -Message "Execution Finished.  No Errors Detected. Not Sending Events Email"
  }
}

Elseif ($EmailLevel -eq "Verbose")  #If the parameters indicate to always email, set sendMail flag
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 123 -Message "Execution Finished.  Verbose Email Selected.  Sending Events Email"
  $sendMail = $true
}

else
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 124 -Message "Execution Finished. No Email Selected. "
  $sendMail = $false
}

if($sendMail)  # If sendMail flag is set, then generate the message, and send it
{
  $Events = Get-EventLog -LogName "Application" -Source $LogName -After $(Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-1)
  $mailBody += $Events | Select-Object -Property TimeGenerated, EventID, EntryType, Source, Message | ConvertTo-HTML -Head $mailHead|  Out-String
  Send-MailMessage -To $smtpTo -From $smtpFrom -Subject $mailSubject -BodyAsHtml -Body $mailBody -SmtpServer $smtpServer
}
