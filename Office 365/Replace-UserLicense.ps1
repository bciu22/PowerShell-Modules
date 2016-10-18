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


$OldLicense = "bucksiu:STANDARDWOFFPACK_FACULTY"
$NewLicense = "bucksiu:STANDARDWOFFPACK_IW_FACULTY"

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

$UsersWithOldLicense = $users | ?{$(Has-UserLicense -user $_ -AccountSkuIU $OldLicense)}

Foreach ( $User in $UsersWithOldLicense )
{
    Write-Host "Updating User License for $($User.UserPrincipalName) from $OldLicense to $NewLicense"
    $User | Set-MsolUserLicense -AddLicenses $NewLicense -LicenseOptions $LicenseOptions  -RemoveLicenses $OldLicense -ErrorAction "Stop"

}


