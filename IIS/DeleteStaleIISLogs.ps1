<#
  .SYNOPSIS
    Script to remove stale files

  .DESCRIPTION
    Remove stale IIS Log files based on age

  .PARAMETER IISLogTarget
    Directory from which to remove old files
    
  .PARAMETER Days
    file age limit
    
  .PARAMETER Extension
    What files to investigate
    
  .PARAMETER EmailLevel

  .NOTES
    Authors: Dan Lezoche, Charles Crossan
#>
[CmdletBinding()]
Param(
  [Parameter()]
  $Days = "7",
  [Parameter()]
  $Extension = "*.log",
  [Parameter()]
  [ValidateSet('Error','Verbose','None')]
  $EmailLevel="Error"
)
$LogName = "Log File Cleanup Script"
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

# Get today's date
$Now = Get-Date
$mailSubject = $cn + ": DeleteStaleIISLogs " + $Now
$mailBody = "$cn" + " $Now " + "`r`n`r`n"

# Calculate stale date
$LastWrite = $Now.AddDays(-$Days)

Import-Module WebAdministration

foreach($WebSite in $(get-website))
{
    $IISLogTarget="$($Website.logFile.directory)\w3svc$($website.id)".replace("%SystemDrive%",$env:SystemDrive)

    #Get a list of files in the directory that meet the requirements
    $Files = Get-Childitem $IISLogTarget -Include $Extension -Recurse | Where {$_.LastWriteTime -le "$LastWrite"}

$LogLine = @"
Starting Log Cleanup run.
Website Name: $($WebSite.name)
Hostname: $cn
IISLogTarget: $IISLogTarget
Days: $Days
LastWrite: $LastWrite
"@

    Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 100 -Message $LogLine

    foreach ($File in $Files) 
    {
      Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 101 -Message "Deleting stale files in $IISLogTarget"
      if ($File -ne $NULL)
      {
        Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 102 -Message "Deleting File $File"
        Remove-Item $File.FullName | Out-Null
      }
      else
      {
        Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 103 -Message  "No more files to delete!"
      }
    }
    Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 104 -Message "Completed execution for $($WebSite.name)"
}

#Get the Events from the Error Log
$Events = Get-EventLog -LogName "Application" -Source $LogName -After $(Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-1)
#Count the errors
$ErrorCount =  $Events | ?{$_.EntryType -eq "Error" }  | Measure-Object | Select-Object -ExpandProperty Count

If($EmailLevel -eq "Error")  #If there were errors, and the parameters indicate to email on errors, set sendMail flag
{
  if($ErrorCount -gt 0)
  {
    Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 105 -Message "Execution Finished.  Errors Detected. Sending Events Email"
    $sendMail = $true
  }
  else
  {
    Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 106 -Message "Execution Finished.  No Errors Detected. Not Sending Events Email"
  }
}

Elseif ($EmailLevel -eq "Verbose")  #If the parameters indicate to always email, set sendMail flag
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 107 -Message "Execution Finished.  Verbose Email Selected.  Sending Events Email"
  $sendMail = $true
}

else
{
  Write-EventLog -LogName "Application" -Source $LogName -EntryType Information -EventID 108 -Message "Execution Finished. No Email Selected. "
  $sendMail = $false
}

if($sendMail)  # If sendMail flag is set, then generate the message, and send it
{
  $Events = Get-EventLog -LogName "Application" -Source $LogName -After $(Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-1)
  $mailBody += $Events | Select-Object -Property TimeGenerated, EventID, EntryType, Source, Message | ConvertTo-HTML -Head $mailHead|  Out-String
  Send-MailMessage -To $smtpTo -From $smtpFrom -Subject $mailSubject -BodyAsHtml -Body $mailBody -SmtpServer $smtpServer
}



