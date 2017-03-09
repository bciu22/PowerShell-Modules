<#
    .DESCRIPTION
        Modify all InfoPath forms within a library.  
        Increment the version nubmer
        Add a node to the schema
        Set the value of hte new node

    .EXAMPLE
        $oldForm = [xml]$(Get-Content -Raw 'Form.xml')
        $test = Upgrade-SPInfoPathForm $oldForm
        $test.outerxml | Out-File -FilePath "Upgraded.XML" -Encoding utf8

#>


#region Functions

    Function Upgrade-SPInfoPathForms
    {
        Param(
            $WebURL
        )
     
        $web = Get-SPWeb "https://sharepoint.bucksiu.org/"
        $list = $web.Lists.TryGetList("Forms")
        $esyForms = $list.RootFolder.Files | 
            Where-Object {$_.Properties._88cfb56f_1b05_402f_a667_736bda2e7e86 -eq "ESY"} |
            Where-Object {$_.Properties._20a0bfc6_23e2_44e5_ac91_5b86d34edd2c -eq "approver"}

        $formsToProcess = $esyForms # | Select-Object -First 10

        Foreach ($file in $formsToProcess)
        {

            $Form = [xml]$([System.Text.Encoding]::ASCII.GetString($file.OpenBinary()))
            $Form.outerxml | Out-File -FilePath "c:\Forms\$($File.Title)" -Encoding utf8
            switch ($form.myFields.ProposedTitleProgramLocation.ProposedEmployeeType)
            {
                "IA" { $BudgetCode = "aaaaaaaaaaaaaa" }

            }
            $formVersion = Get-SPInfoPathFormVersion -FormXML $form
            Write-Host "Processing Form: $($File.Title)"
            Write-Host "Version: $($formVersion.solutionVersion )"
            if ($formVersion.solutionVersion -eq "1.0.0.1043" )
            {
                Write-Host "Form Schema current, Writing value only"
                 $NewForm = Set-SPInfoPathFormBudgetCode -FormXML $Form -BudgetCode $BudgetCode
            }
            else {
                Write-Host "Form Schema old.  Updating from version $($formVersion.solutionVersion)"
                 $NewForm = Upgrade-SPInfoPathForm -FormXML $Form -BudgetCode $BudgetCode
            }
           
            if ($NewForm.myFields.ESYOnlyData.ESYBudgetCode.innerXML -ne "")
            {
                $file.SaveBinary([System.Text.Encoding]::ASCII.GetBytes($NewForm.OuterXML))
            }

            

        }
    }

    Function Get-SPInfoPathFormVersion
    {
         Param(
            $FormXML
         )

        $VersionInfo = New-Object -TypeName PSObject

        $regex = '(\w.*?=".*?"\s?)'
        $allMatches = [regex]::matches($($formxml.'mso-infoPathSolution'),$regex)

        foreach ($m in $allMatches)
        {
        $r = $m.value.split("=")
        $VersionInfo | Add-Member -MemberType NoteProperty -Name $r[0] -Value $($($r[1] -replace ('"','')).trim())
        }
        $VersionInfo
    }

    function Set-SPInfoPathFormBudgetCode
    {
        Param(
            $FormXML,
            $BudgetCode
        )

        $FormXML.myFields.ESYOnlyData.ESYBudgetCode = $BudgetCode

        $FormXML
    }


    Function Upgrade-SPInfoPathForm
    {
        Param(
            $FormXML,
            $BudgetCode
        )

        #[System.Xml.XmlNamespaceManager] $nsm = new-object System.Xml.XmlNamespaceManager $FormXML.NameTable
        #$nsm.AddNamespace("my", "http://schemas.microsoft.com/office/infopath/2003/myXSD/2015-11-20T15:00:15")

        $FormXML.'mso-infoPathSolution' = 'name="urn:schemas-microsoft-com:office:infopath:PAFCOS:-myXSD-2015-11-20T15-00-15" solutionVersion="1.0.0.1043" productVersion="14.0.0.0" PIVersion="1.0.0.0" href="https://oldportal.bucksiu.org/PAFPortal/FormServerTemplates/PAFCOS.xsn"'
        $ESYData = $FormXML.CreateElement("my","ESYOnlyData", "http://schemas.microsoft.com/office/infopath/2003/myXSD/2015-11-20T15:00:15") 
        $ESYBudgetCode = $FormXML.CreateElement("my","ESYBudgetCode", "http://schemas.microsoft.com/office/infopath/2003/myXSD/2015-11-20T15:00:15")
        $ESYBudgetCode.InnerXML = $BudgetCode
        $ESYData.AppendChild($ESYBudgetCode) | out-null
        $FormXML.myFields.AppendChild($ESYData) | out-null
        $FormXML

    }

    Function Get-AllTitles{
        $web = Get-SPWeb "https://sharepoint.bucksiu.org/"
        $list = $web.Lists.TryGetList("forms")
        $esyForms = $list.RootFolder.Files | Where-Object {$_.Properties._88cfb56f_1b05_402f_a667_736bda2e7e86 -eq "ESY"} 

        #$FomMetadata = $esyForms | Select-Object -Property *, @{Name="Assignee";expr={$_.Properties._20a0bfc6_23e2_44e5_ac91_5b86d34edd2c}} 

        $formsToProcess = $esyForms | Select-Object -First 100

        Foreach ($file in $esyForms)
        {
            try{
                $Form = [xml]$([System.Text.Encoding]::ASCII.GetString($file.OpenBinary()))
                $form.myFields.ProposedTitleProgramLocation
            }
            catch
            {
                Write-Error "Error Opening $($file.Title)"
            }
            
        }
    }
   

#endregion


Upgrade-SPInfoPathForms 