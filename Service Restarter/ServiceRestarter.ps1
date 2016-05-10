<#
  .DESCRIPTION 
    Watch for a single process, and if it terminates, restart the process
    
  .PARAMETER
    Service Name

#>
[CmdletBinding()]
Param(
  [Parameter()]
  $ProcessName,
  [Parameter()]
  $ServiceName
)
try
{
  . "$PSScriptRoot\config.ps1"

}
catch
{
  Write-Error "Unable to load config file.  Exiting."
  break
}
$timer = 5
while ($true)
{

  $Process = Get-Process $ProcessName
  if(!$Process)
  {
   
    Write-Verbose "The service is not running.  Attempting restart"
    try
    {
        Stop-Service $ServiceName -ErrorAction Stop
        Start-Service $ServiceName -ErrorAction Stop
        Write-Verbose "Service Restarted"
        Send-MailMessage -To $smtpTo -From $smtpFrom -Subject "Service Failed: $ServiceName" -Body "Service Failed: $ServiceName.  It has been restarted" -SmtpServer $smtpServer
        $timer = 5
    }
    catch
    {
        Write-Verbose "Unable to restart service"
        Send-MailMessage -To $smtpTo -From $smtpFrom -Subject "Service Failed: $ServiceName" -Body "Service Failed: $ServiceName.  It could not be restarted" -SmtpServer $smtpServer
        $timer = 900
    }    
  }
  else
  { 
    Write-Verbose "The specified process is running"
  }  
  Start-Sleep -Seconds $timer

}