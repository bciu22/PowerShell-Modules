# SCCM Detection Logic (PowerShell)
```
#Set minimum bios version
$BIOSMinimum = "1.10.5"
#Convert BiosMinimum to array
$ArrayBIOSMinimum = $BIOSMinimum -Split '\.'

#Get BIOS config
$BIOS = Get-WmiObject Win32_Bios
$BIOSCurrent = $BIOS.SMBIOSBIOSVERSION
$ArrayBIOSCurrent = $BIOSCurrent -Split '\.'

#sanity check; iterate through entire smaller array, try to avoid IOB for inbalanced arrays
If($ArrayBIOSMinimum.Count -lt $ArrayBIOSCurrent.Count)
{
    $i = $ArrayBIOSMinimum.Count
}
Else #equal or greater than; use current
{
    $i = $ArrayBIOSCurrent.Count
}

#Iterate through array, comparing MinVersion against current
For($x = 0; $x -lt $i; $x++)
{
    If([Int]$ArrayBIOSCurrent[$x] -gt [Int]$ArrayBIOSMinimum[$x])
    {
        #current is higher; we're finished
        #Write-Host "Current BIOS is higher"
        $retVal = 0
        break;
    }
    ElseIf([Int]$ArrayBIOSCurrent[$x] -lt [Int]$ArrayBIOSMinimum[$x])
    {
        #A mismatch has been found, set flag to False
        #Write-Host "Current BIOS is lower"
        $retVal = 1
        break;
    }
    Else
    {
        #indexes match; we must continue processing
        $retVal = 2
    }
}
Switch ($retVal)
{
    0 {Write-Host "Current BIOS is Higher than Minimum"; break; <#write to STDOUT for success#>}
    1 {break; <#Write nothing; evaluate to fail in detection logic#>}
    2 {Write-Host "Current BIOS Matches Minimum"; break; <#write to STDOUT for success#>}
}
```

# SCCM Return Code (Dell BIOS Returns are non-standard)

 - Value: 2 
 - Code Type: Soft Reboot 
 - Name: REBOOT_REQUIRED 
 - Description: c/o Dell's 'Dell Update Package' documentation - a return code of 2    requires a reboot to complete
