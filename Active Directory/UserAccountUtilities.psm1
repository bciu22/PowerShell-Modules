function Replace-AttributeInDirectory{
param(
$AttributeName,
$OldAttributeValue,
$NewAttributeValue
)

	$parameters = @{}
	$Parameters.Add($AttributeName,$NewAttributeValue)
	Switch ($AttributeName)
	{
		"Office"
		{
			$Filter = "$AttributeName -like ""$OldAttributeValue"""
		}
		default{
			$Filter = "$AttributeName -eq ""$OldAttributeValue"""
		}
	}
	$filter
	
	$Users = Get-ADUser -Filter $Filter -Properties $AttributeName
	$Users | ft -property Name, $AttributeName, @{Expression={$NewAttributeValue};Label="New Value"}
	
	$title = "Confirm Attribute Change for Above Users"
	$message = "Are you sure you want to change the attribute for these users?"
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Change all users $Attribute to $NewAttributeValue"
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Do not change"
	
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
	$result = $host.ui.PromptForChoice($title, $message, $options, 1) 
	switch ($result)
	{
			0 
			{
				$Users | Set-ADUser @parameters -Confirm:$TRUE
			}
			1 
			{
				"You selected No"
			}
	}
}