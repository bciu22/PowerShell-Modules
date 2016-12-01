Function Remove-Spam{
<#
	.DESCRIPTION
	The Remove-Spam function executes a Search-Mailbox query against Exchange given appropriate search parameters.  If not specified, the function with operate in "LogOnly" mode.
	
	.PARAMETER Identity
	Identity of the mailbox to search
	
	.PARAMETER SubjectLine
	String to search for in the subject line
	
	.PARAMETER Attachment
	String to search for in attached file names OR boolean "attachment exists"?
	
	.PARAMETER FromAddress
	String to search for in the from: field

    .PARAMETER ToAddress
    String to search for in the to: field

    .PARAMETER BodyLanguage
    String to search for in the email body (NOT WORKING)

    .PARAMETER PriorDays
    Integer of how many days back to search

    .PARAMETER TargetMailbox
    Name of mailbox to store Search-Mailbox results

    .PARAMETER TargetFoler
    Name of mailbox folder to store results - Fixed 06092015

    .PARAMETER LogOnly
    If not set will default to LogOnly.

    .PARAMETER Delete
    Boolean value enabling DeleteItem to be executed, can only be used if LogOnly = $False or LogOnly is not set.  
	
	.EXAMPLE
	Remove-Spam -Subject "Click here for a free car!" -Delete
	
	
	.NOTES
	Written by Charles Crossan.
    Written by Dan Lezoche.
	https://technet.microsoft.com/en-us/library/dn774955(v=exchg.150).aspx



#>
	[CmdletBinding()]
	Param(
	[Parameter(Mandatory=$False,Position=1)]
	[String]$SubjectLine,
	[Parameter(Mandatory=$False,Position=2)]
	[String]$Attachment,
	[Parameter(Mandatory=$False,Position=3)]
	[String]$FromAddress,
	[Parameter(Mandatory=$False,Position=4)]
	[String]$ToAddress,
	[Parameter(Mandatory=$False,Position=5)]
	[String]$BodyLanguage,
	[Parameter(Mandatory=$False,Position=6)]
	[String]$PriorDays,
	[Parameter(Mandatory=$False,Position=7)]
	[String]$TargetMailbox="SpamDump",
	[Parameter(Mandatory=$False,Position=8)]
	[String]$TargetFolder= "Spam - $(Get-Date -format d)$(Get-Date -format t)",
	[Parameter(Mandatory=$False,Position=9)]
	[String]$Identity,
	[Parameter()]
	[Switch]$LogOnly,
	[Parameter()]
	[Switch]$Delete =$FALSE,
	[Parameter()]
	[String]$Database
	)

	$searchterms = @()
	$parameters = @{}
	$parameters.Add("LogLevel","Full")

	if($SubjectLine)
	{	
		$searchterms +="Subject:""$($SubjectLine)"""
	}

	if($Attachment)
	{	
		$searchterms +="Attachment:$($Attachment)"
	}

	if($FromAddress)
	{	
		$searchterms +="From:$($FromAddress)"
	}

	if($ToAddress)
	{	
		$searchterms +="To:$($ToAddress)"
	}

	if($BodyLanguage)
	{	
		$searchterms +="Body:""$($BodyLanguage)"""
	}

	if($PriorDays)
	{	
		$StartDate=$(Get-Date).AddDays(-$PriorDays)
		$searchterms +="Received > $($StartDate.ToShortDateString())"
	}
	
	if($LogOnly -OR $Delete -eq $FALSE)
	{
		Write-Host -ForegroundColor Yellow "Operating in LogOnly Mode"
		$Parameters.Add("LogOnly",$true)
	}
	if($Delete -eq $True)
	{
		$Parameters.Add("DeleteContent",$true)
	}

	$Parameters.Add("TargetMailbox",$TargetMailbox)
	$Parameters.Add("TargetFolder",$TargetFolder)

	$SearchString = $($searchterms -join " AND ")

	$Parameters.Add("SearchQuery","$SearchString")
	$parameters

	if($Identity)
	{
	& Get-Mailbox $Identity | Search-Mailbox  @Parameters
	}
	else
	{
	#$Mailboxes = Get-Mailbox -ResultSize Unlimited
	& Get-Mailbox -Database $(Get-MailboxDatabase $Database) -ResultSize Unlimited | Search-Mailbox  @Parameters
	}
	#or, if you want to do specific sources: @( "mailbox1", "mailbox2", "mailbox3", "mailbox4", "") | Get-mailbox | Search-Mailbox -SearchQuery {Subject:"Detected an unauthorized user attempting to access the SNMP interfac"} -TargetMailbox "spamdump" -TargetFolder "Derp" -LogOnly -LogLevel full
}