# PowerShell-Modules
A Collection of PowerShell Scripts and Modules

##Exchange Modules

###Message Utilities.psm1
Usage: Import-Module MessageUtilities.psm1

#### Remove-Spam
  * Provides a parameterized function for the built in Exchange eDiscovery features abstracting the construction of AQS and KQL queries into PowerShell parameters.

  * Example: Remove-Spam -Subject "Click here for a free car!" -Delete

##Active Directory Modules

### UserAccountUtilities.psm1
Usage Import-Module UserAccountUtilities.psm1

#### Replace-AttributeInDirectory
  * A method to conditionally update the property of all AD accounts from the specified value to the new value
  
  * Examplpe: Replace-AttributeInDirectory -AttributeName Office -OldAttributeValue "China" -NewAttributeValue "London"


##Office 365 Modules
