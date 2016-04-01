<#
	.SYNOPSIS
	This script will iterate through all SCCM task sequences, and update the boot image on each task sequence with the platform variant that cooresponds to the new boot image.  Update the variables containing the Package IDs of the old and new boot images before execution.

#>

#-- Update These variables before execution--#
$Oldx64Boot = "70500184"
$Newx64Boot = "705002C8"

$Oldx86Boot = "7050015B"
$Newx86Boot = "705002C7"

#-- Do not modify --#
Get-CMTaskSequence | Foreach-Object {
	if($_.BootImageID -eq $Oldx64Boot )
	{
		$NewBootID = $Newx64Boot #64 Bit
	}
	elseif($_.BootImageID -eq $Oldx86Boot)
	{
		$NewBootID = $Newx86Boot #32 Bit
	}
	#"$($_.Name) $NewBootID"
	$_.BootImageID = $NewBootID
	$_.put()
}