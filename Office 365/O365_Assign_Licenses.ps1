<#
  .SYNOPSIS
    This script will update O365 licenses and usage locations for students and teachers
  
  .DESCRIPTION
    This connects to O365 through parameters defined in config.ps1 located in the same directory.  It evaluates O365 licenses and usage locations for two license types correlated to the values defined in config.ps1.
  
  .PARAMETER Commit
    False by default.  Setting this flag causes the script to make changes against the O365 environment.  Leaving this flag unset will cause the script to run in "read-only" mode, and no changes will be made.
  
  .PARAMETER EmailLevel
    Specify the circumstances under which this script will send email messages.  On "Error" by default, so email will only be sent if the script encounters an error.  "Verbose" will always send an email upon completion of a run.  "None" will never send an email.
    
  .PARAMETER UpdateAllLicenses
    If set to true, then update the "DisabledPlans" for all O365 users.  Otherwise, only apply licenses to unlicensed users.
  
  .PARAMETER UserLimit
    If set to 0, operate on all users.  Else, limit O365 users to this value.
  
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
  [Switch]$UpdateAllLicenses=$False,
  [Parameter()]
  [ValidateSet('Error','Verbose','None')]
  $EmailLevel="Error",
  [Parameter()]
  $UserLimit=0
)
$ExecutionStartTime = Get-Date
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

Function Set-O365License
{
  <#
    .DESCRIPTION
      This function will SET the license for an O365 User.   It is a wrapper function for the Set-MsolUserLicense function that addresses 
      some weaknesses with the default function such as altering licenses on existing accounts.

  #>
  param(
    $MSOLUserAccount,
    $License,
    $LicenseOptions,
    $Commit
  )
 
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 113 -Message "Processing license: $License for $($MSOLUserAccount.UserPrincipalName)"
  Try
  {
    ##### Here, we need to see what licenses the user already has, and deal with the delta
    if($MSOLUserAccount.isLicensed)
    {
      #Since there are multiple license SKUs, we must determine if the user actually has the desired license on their account.
      $OperableLicense = $MSOLUserAccount.Licenses | ?{$_.AccountSkuID -eq $License}
      if ($OperableLicense.count -eq 1 )
      {
        If($Commit)
        {  
          Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 119 -Message "User $($MSOLUserAccount.UserPrincipalName) has the $License assigned.  Setting DisabledPlans to: $($LicenseOptions.DisabledServicePlans -join ',')  "
          $MSOLUserAccount | Set-MsolUserLicense -LicenseOptions $LicenseOptions -ErrorAction "Stop"
        }
        else
        {
          Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 129 -Message "WhatIf: User $($MSOLUserAccount.UserPrincipalName) has the $License assigned.  Setting DisabledPlans to: $($LicenseOptions.DisabledServicePlans -join ',')  "
        }
       
      }
      else 
      {
        # The user IS LICENSED in some capacity, but not with the desired license AccountSkuID.  Instead of klobbering the existing license, let's generate a warning in the event log.
        $UserAssignedLicenses = $($MSOLUserAccount.Licenses | Select-Object -ExpandProperty AccountSkuID) -join ','
        Write-EventLog -LogName "Application" -Source $LogName -EntryType Warning -EventID 118 -Message @"
User $($MSOLUserAccount.UserPrincipalName) is licensed, but does not have the $License assigned.
Currently assigned licenses are: $UserAssignedLicenses.  
Unable to update license options
"@
      }
    }
    else 
    {
      If($Commit)
      {  
        Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 120 -Message "User $($MSOLUserAccount.UserPrincipalName) was not previously licensed.  Applying license: $License."
        $MSOLUserAccount | Set-MsolUserLicense  -AddLicenses $License -LicenseOptions $LicenseOptions -ErrorAction "Stop"
      }
      else
      {
        Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 130 -Message "WhatIf: User $($MSOLUserAccount.UserPrincipalName) was not previously licensed.  Applying license: $License."
      }
      #User account was not licensed.  Add the supplied license to the account
     
    }
  }
  catch
  {
    Write-EventLog -LogName "Application" -Source $LogName -EntryType Error -EventID 114 -Message "Assign License Failed $($_ | out-string)"
  }   
}

#Script Defaults
#create emtpy arrays for staff/students
$Faculty = @()
$Students = @()
$ProblemAccounts = @()

#Configure services to be applied
$FacultyPlanService = New-MsolLicenseOptions -AccountSkuId $FacultyLicense -DisabledPlans $FacultyDisabledPlans
$StudentPlanService = New-MsolLicenseOptions -AccountSkuId $StudentLicense -DisabledPlans $StudentDisabledPlans




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
#Discover all unlicensed accounts up to the user limit parameter
if($UserLimit -eq 0)
{
  $Users = Get-MSOLUser -All 
}
else {
   $Users = Get-MSOLUser -MaxResults $UserLimit
}

$Unlicensed = $Users | Where-Object{$_.IsLicensed -ne $True}
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 104 -Message "Unlicensed accounts found: $($Unlicensed.Count)"
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 127 -Message "Total accounts found: $($Users.Count)"

#Normalize Student OU
If(!$StudentOU.StartsWith("*"))
{
  $StudentOU = "*" + $StudentOU
}

Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 105 -Message "Analyzing accounts for Student/Facility licensing"
#Determine students/faculty based on UPN and AD OU
if ($UpdateAllLicenses)
{
  #If the UpdateAllLicenses flag was set, then we should update the license for the entire found set of users
  $UsersToProcess = $Users
}
else {
  #If the UpdateAllLicenses flag was not set, then we should only set the license for unlicensed users
  $UsersToProcess = $Unlicensed
}
ForEach($User in $UsersToProcess)
{
  #Get the AD Object based on UPN, which MSonline 
  $x = Get-ADUser -Filter {UserPrincipalName -eq $User.UserPrincipalName}
  #Determine if the account lives in a student OU, otherwise it's staff
  If($x.DistinguishedName -ilike $StudentOU)
  {
    $Students += $User
  }
  Else
  {
    if ($x)  # If the local AD object exists, and it's not a student then assume a faculty
    {
      $Faculty += $User
    }
    else  #If the local AD Object doesn't exist, then this is a problem user.
    {
      $ProblemAccounts += $User
    }
  }
}
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 106 -Message "Students: $($Students.Count)"
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 107 -Message "Faculty: $($Faculty.Count)"
if ($ProblemAccounts.count -gt 0)
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Warning -EventID 128 -Message "Problem Accounts ($($ProblemAccounts.Count)): `r`n$($ProblemAccounts -join "`r`n")"
}

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
    Set-O365License -MSOLUserAccount $student -License $StudentLicense -LicenseOptions $StudentPlanService -Commit $Commit
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
    Set-O365License -MSOLUserAccount $staff -License $FacultyLicense -LicenseOptions $FacultyPlanService -Commit $Commit
  }
}
Else
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 121 -Message "No Faculty licenses necessary, skipping"
}

#Get the Events from the Error Log
$Events = Get-EventLog -LogName "Application" -Source $LogName -After $ExecutionStartTime
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
  $mailBody += $Events | Select-Object -Property TimeGenerated, EventID, EntryType, Source, Message | ConvertTo-HTML -Head $mailHead|  Out-String
  Send-MailMessage -To $smtpTo -From $smtpFrom -Subject $mailSubject -BodyAsHtml -Body $mailBody -SmtpServer $smtpServer
}
