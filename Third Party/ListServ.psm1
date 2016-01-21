<#
	.SYNOPSIS
		LISTSERV PowerShell List Management Functions
	.DESCRIPTION
		ListServ's built in management is awful, but thankfully they give us access to the plain text files.  Let's represent them as objects so we can preform 21st century management operations on lists.
	.NOTES
		Version:		1.0
		Author:			Charles Crossan
		Creation Date:	12/17/2015
		Purpose/Change:	Initial Creation
	
#>


function Get-List{
[cmdletbinding()]
param(
$ListFile
)
<#
.SYNOPSIS
	Read a LISTSERV List file, and return a PowerShell Object representing the list
.EXAMPLE
	Find All Lists containing Charles
	$Lists = Get-ChildItem -Path .\MAIN\ -Filter *.LIST | %{Get-List $_.FullName}
	$Lists | %{ $_ | %{ $MS = $_.members | ?{$_.Name -like "*Lesley Carr*"}; if ($MS) {$_.ListName} }}
	$Lists | %{ $_ | %{ $MS = $_.owners | ?{$_.Name -like "*Lesley Carr*"}; if ($MS) {$_.ListName} }}
	$Lists | %{ $_ | %{ $MS = $_.senders | ?{$_.Name -like "*Lesley Carr*"}; if ($MS) {$_.ListName} }}
	$Lists | %{ $_ | %{ $MS = $_.Senders | ?{$_.Name -like "*Lesley Carr*"}; if ($MS) {[PSCustomObject]@{"List Name"= $_.ListName; "Search Member"= $MS | select-object -expandproperty Email; "Owners"=$_.owners | select-object -expandproperty Email} }} }  | Select-Object "List Name" | cli
#>
	$PATHTOLISTEXE = '\\LISTS.bucksiu.org\C$\Program Files\LISTSERV\MAIN'
	$LISTContent =$null
	$LISTContent = &("$PATHTOLISTEXE\listview.exe") $ListFile
	$ListName = ""
	$ListObject = New-Object psobject
	$Members = @()
	$Owners = @()
	$Senders = @()
	$matches=$null
	$LISTContent.split("`n")| Foreach-Object{
		if ($_ -match('(\* )(\w.*?)$') -and $_ -notmatch('=') -and $_ -notmatch('\* \.') )
		{
			Write-Verbose "List Name Line: $_"
			Add-Member -InputObject $ListObject -MemberType NoteProperty -Name "ListName" -Value $($matches[2])
		}
		elseif ($_ -match('=') -and $_ -match('(\* )(\w.*?)$'))
		{
			$ConfigLine = $matches[2]
			$ConfigLine -match('(.*?)=\s?(.*?)$') | Out-Null
			if($matches[1] -eq "Owner")
			{
				Write-Verbose "Owner Line: $_"
				$ownerLine = $matches[2]
				$ownerLine -match('(.*?)\s(.*)') | Out-Null
				$Owners += [pscustomobject]@{Email=$matches[1]; Name=$matches[2]}
			}
			elseif($matches[1] -eq "Send")
			{
				Write-Verbose "Sender Line: $_"
				$ownerLine = $matches[2]
				$ownerLine -match('(.*?)\s(.*)') | Out-Null
				$Senders += [pscustomobject]@{Email=$matches[1]; Name=$matches[2]}
			}
			else
			{
				Write-Verbose "Config Line: $_"
				Add-Member -InputObject $ListObject -MemberType NoteProperty -Name $matches[1] -Value $($matches[2])
			}
		}
		elseif ($_ -match('(.*?)\s(.*?)\s{2,}(.*)'))
		{
			Write-Verbose "MEmber Line: $_"
			$Members += [pscustomobject]@{Email=$matches[1]; Name=$matches[2]; Password=$matches[3]; Username=$($matches[1].split("@")[0]); Domain=$($matches[1].split("@")[1])}
		}
		
	}
	Add-Member -InputObject $ListObject -MemberType NoteProperty -Name "Senders" -Value $Senders
	Add-Member -InputObject $ListObject -MemberType NoteProperty -Name "Owners" -Value $Owners
	Add-Member -InputObject $ListObject -MemberType NoteProperty -Name "Members" -Value $Members
	$ListObject
}