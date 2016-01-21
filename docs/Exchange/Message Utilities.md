# Message Utilities.psm1
This module contains many useful cmdlets for administering Exchange Server.
Usage: `Import-Module MessageUtilities.psm1`

#### Remove-Spam
  * Provides a parameterized function for the built in Exchange eDiscovery features abstracting the construction of AQS and KQL queries into PowerShell parameters.

  * Example: `Remove-Spam -Subject "Click here for a free car!" -Delete`
