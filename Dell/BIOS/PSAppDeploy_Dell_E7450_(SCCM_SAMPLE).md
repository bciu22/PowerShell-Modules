#SCCM Detection Logic (PowerShell)
```
#Set minimum bios version
$BiosMinimum = "A10"

#Get BIOS config
$Bios = Get-WmiObject Win32_Bios

#Check for minimum version
If($Bios.SMBIOSBIOSVersion -ge $BiosMinimum)
{
    #requirements met, write something to output
    Write-Host "BIOS is current"
}
#requirements not met, return nothing
```

#SCCM Return Code (Dell BIOS Returns are non-standard)
Value: 2
Code Type: Soft Reboot
Name: REBOOT_REQUIRED
Description: c/o Dell's 'Dell Update Package' documentation - a return code of 2 requires a reboot to complete
