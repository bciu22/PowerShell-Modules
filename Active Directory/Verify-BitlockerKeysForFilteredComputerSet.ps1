Function Get-BitLockerObjects{
param(
$ComputerDistinguishedName
)
return Get-ADObject -Filter {objectclass -eq 'msFVE-RecoveryInformation'} -SearchBase $ComputerDistinguishedName -Properties 'msFVE-RecoveryPassword'
}

$Newcomputers = Get-ADComputer -Filter {Name -like "*<PC Name Here>*"}

$Newcomputers | Foreach-Object {
	
	$BitLockerObjects = Get-BitLockerObjects -ComputerDistinguishedName $_.DistinguishedName
	if ($BitLockerObjects)
	{
		#$BitLockerObjects
	}
	else
	{
		"No BitLocker Keys Found for $_.DistinguishedName"
	}

}