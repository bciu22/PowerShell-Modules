#Get All lists for which a user has send permission:

function Get-SendersEnabledDistributionGroups
{
param(
$UserName
)

	$dn = Get-ADUser $UserName | Select-Object -ExpandProperty DistinguishedName
	Get-DistributionGroup | ?{$_.AcceptMessagesOnlyFrom | ?{$_.DistinguishedName -eq $dn}} 
	Get-DynamicDistributionGroup | ?{$_.AcceptMessagesOnlyFrom | ?{$_.DistinguishedName -eq $dn}} 
}

Function Set-SenderEnabledDistributionGroups
{
param(
$Group,
$Users
)
	if ($Group.GetType().Name -eq "DistributionGroup")
	{
		Set-DistributionGroup -Identity $Group -AcceptMessagesOnlyFrom $Users
	}
	elseif ($Group.getType().Name -eq "DynamicDistributionGroup")
	{
		Set-DynamicDistributionGroup -Identity $Group -AcceptMessagesOnlyFrom $Users
	}
}

$searchUser = <>
$addUser = <>

$DGs = Get-SendersEnabledDistributionGroups -UserName $searchUser 
$DGs | %{$_.DisplayName}
$DGs | Foreach-Object{
	Set-SenderEnabledDistributionGroups -Group $_ -Users @{Add=$addUser}
}