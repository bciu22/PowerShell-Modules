function Parse-MatchGroups {
    param (
        $Match
    )
    $badMail = New-Object –TypeName PSObject
    $badMail | Add-Member -MemberType NoteProperty -Name "Recipients" -Value $($($Match.groups[1].value) -split ';')[1]
    $badMail | Add-Member -MemberType NoteProperty -Name "Action" -Value $Match.groups[2].value
    $badMail | Add-Member -MemberType NoteProperty -Name "Status" -Value $Match.groups[3].value
    $badMail | Add-Member -MemberType NoteProperty -Name "Diagnosic-Code" -Value $Match.groups[4].value

    $badMail

}


function Get-BadMailItem {
    Param (
        $FileName
    )

    $badMails  = @()
    $string = [io.file]::ReadAllText($FileName) 

    $recipients = $string |  Select-String -Pattern '(?smi)Final-Recipient: (.*?)\sAction: (.*?)\sStatus: (.*?)\sDiagnostic-Code: (.*?)$' -AllMatches

    if ($recipients.matches -is [system.array])
    {
        foreach ($recipient in $recipients.matches)
        {
            Parse-MatchGroups -Match $recipient
        }
    }
    else {
        return
        Parse-MatchGroups $recipients.matches
    }
  

   

}

Function Parse-Logs
{
    Get-ChildItem -Path "C:\inetpub\mailroot\Badmail" -Filter "*.bad" | ForEach-Object {
        Get-BadMailItem -FileName $_.FullName
    }
}

Parse-Logs | Select-Object Recipients