<#
  .SYNOPSIS
    This script will execute robocopy against a source and a target directory
  
  .DESCRIPTION
    This executes robocopy against a source and a target directory providing windows event logs, and optional email alerts.
  
  .PARAMETER EmailLevel
    Specify the circumstances under which this script will send email messages.  On "Error" by default, so email will only be sent if the script encounters an error.  "Verbose" will always send an email upon completion of a run.  "None" will never send an email.
    
  .LINK
  
  .NOTES
    Authors: Charles Crossan, Dan Lezoche

#>
[CmdletBinding()]
Param(
  [Parameter()]
  [ValidateSet('Error','Verbose','None')]
  $EmailLevel="Error"
)
$LogName = "PowerRoboCopy File Copy Script"
#Setup Logging
if(![System.Diagnostics.EventLog]::SourceExists($LogName))
{
  New-EventLog -LogName "Application" -Source $LogName
}
#Import Configuration Parameters
try
{
  . "$PSScriptRoot\config.ps1"
  Import-Module -Force "$PSScriptRoot\functions.psm1"
}
catch
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Error -EventID 126 -Message "Error loading config file.  Stopping execution.  Please ensure that config.ps1 is present in the same directory as the script, and that it is valid."
  Break
}



#Setup Email Destination for Reporting
$Now = Get-Date
$mailSubject = $cn + ": PowerRoboCopy " + $Now
$mailBody = "$cn" + " $Now " + "`r`n`r`n"

$LogLine = @"
Starting PowerRoboCopy run.
Hostname: $cn
Source: $Source
SourceShares: $SourceShares
Target: $Target
RobocopyParams: $RobocopyParams
RobocopyLogParams: $RobocopyLogParams
RobocopyLogDir: $RobocopyLogDir
"@
Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 100 -Message $LogLine

$ErrorCount = 0;
foreach($share in $SourceShares)
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 101 -Message "Mapping Z: to \\$($Source)\$($Share) with username $($SourceShareCredential.UserName)"
	New-PSDrive -Name Z -PSProvider FileSystem -Root \\$source\$share -Credential $SourceShareCredential
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 102 -Message "Initiating copy:  robocopy \\$source\$share \\$target\$share $robocopyparams"
	robocopy \\$source\$share \\$Target\$Share $robocopyParams /LOG+:"$RobocopyLogDir\Log-$Share.txt" $RobocopyLogParams
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 103 -Message "Parsing Copy Results"
  $LogData = @(Get-Content "$RobocopyLogDir\Log-$Share.txt")
  $RCResult = Process-RoboCopyOutput -RoboCopyOutput $LogData
  $ErrorCount += $RCResult.Results.Dirs.Failed + $RCResult.Results.Files.Failed
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 104 -Message @"
Results Parsed.
$($RCResult | FL | Out-String)
$($RCResult.Results | FL | Out-String)
"@
	Remove-PSDrive -Name Z -Force
}

If ($ErrorCount)
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Error -EventID 105 -Message "There were $ErrorCount errors while processing the copy"
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



