Function Update-ApplicationSourcePath {
 [cmdletbinding()]
Param(
$SourceServerFQDN,
$DestServerFQDN,
[parameter(ValueFromPipeline)]
$Application
)
    Process{
        $DeploymentTypes = Get-CMDeploymentType -ApplicationName $Application.LocalizedDisplayName

        ForEach($DeploymentType in $DeploymentTypes) 
        { 
            ## Change the directory path to the new location 
            $DTSDMPackageXML = [XML]$DeploymentType.SDMPackageXML 
    
            ## Get Path for Apps with multiple DTs 
            $OldPath = $DTSDMPackageXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
            $NewPath = $OldPath.Replace($SourceServerFQDN, $DestServerFQDN)
            if ($NewPath -ne $OldPath)
            {
                if($DeploymentType.Technology -eq "MSI")
                {
                    Write-Verbose "Updating $OldPath to $NewPath"
                    $DeploymentType | Set-CMMSIDeploymentType  –ContentLocation $NewPath

                }
                else
                {
                    Write-Verbose "Updating $OldPath to $NewPath"
                    $DeploymentType |Set-CMScriptDeploymentType –ContentLocation $NewPath
                }
            }
        }
      }
}

Function Update-AllApplicationSourcePath
{
 [cmdletbinding()]
Param(
$SourceServerFQDN,
$DestServerFQDN
)

Get-CMApplication | Update-ApplicationSourcePath -SourceServerFQDN $SourceServerFQDN -DestServerFQDN $DestServerFQDN

}

Function Get-AllApplicationSourcePath
{

    Get-CMApplication | Foreach-Object{
        New-Object PSObject -Property @{
            ApplicationName = $_.LocalizedDisplayName;
            SourcePath = $([XML]$_.SDMPackageXML).AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
         }
    }

}


Function Update-DriverSourcePath
{
[cmdletbinding()]
Param(
$SourceServerFQDN,
$DestServerFQDN,
[parameter(ValueFromPipeline)]
$Driver
)
    Process
    {
        $OldPath =  $Driver.ContentSourcePath
        $NewPath = $OldPath.Replace($SourceServerFQDN, $DestServerFQDN)
        if ($NewPath -ne $OldPath)
        {
            Write-Verbose "Updating $OldPath to $NewPath"
            Set-CMDriver -Id $Driver.CI_ID -DriverSource $NewPath
        }
    }
}


Function Update-AllDriverSourcePath
{
 [cmdletbinding()]
Param(
$SourceServerFQDN,
$DestServerFQDN
)

    Get-CMDriver | Update-DriverSourcePath -SourceServerFQDN $SourceServerFQDN -DestServerFQDN $DestServerFQDN
}

Function Get-AllDriverSourcePath
{

    Get-CMDriver | Foreach-Object{
        New-Object PSObject -Property @{
            DriverName = $_.LocalizedDisplayName;
            SourcePath = $_.ContentSourcePath
         }
    }

}


Function Update-DriverPackageSourcePath
{
[cmdletbinding()]
Param(
$SourceServerFQDN,
$DestServerFQDN,
[parameter(ValueFromPipeline)]
$DriverPackage
)
    Process
    {
        $OldPath =  $DriverPackage.PkgSourcePath
        $NewPath = $OldPath.Replace($SourceServerFQDN, $DestServerFQDN)
        if ($NewPath -ne $OldPath)
        {
            Write-Verbose "Updating $OldPath to $NewPath"
            Set-CMDriverPackage -Id $DriverPackage.PackageID -DriverPackageSource $NewPath
        }
    }
}


Function Update-AllDriverPackageSourcePath
{
 [cmdletbinding()]
Param(
$SourceServerFQDN,
$DestServerFQDN
)
    Get-CMDriverPackage | Update-DriverPackageSourcePath -SourceServerFQDN $SourceServerFQDN -DestServerFQDN $DestServerFQDN
}

Function Get-AllDriverPackageSourcePath
{

    Get-CMDriverPackage | Foreach-Object{
        New-Object PSObject -Property @{
            DriverName = $_.Name;
            SourcePath = $_.PkgSourcePath
         }
    }

}



Function Update-PackageSourcePath
{
[cmdletbinding()]
Param(
$SourceServerFQDN,
$DestServerFQDN,
[parameter(ValueFromPipeline)]
$Package
)
    Process
    {
        $OldPath  = $Package.PkgSourcePath
        $NewPath = $OldPath.Replace($SourceServerFQDN, $DestServerFQDN) 
        if ($NewPath -ne $OldPath)
        {
            Write-Verbose "Updating $OldPath to $NewPath"
            Set-CMPackage -Name $Package.Name -Path $NewPath
        }
    }

}


Function Update-AllPackageSourcePath
{
 [cmdletbinding()]
Param(
$SourceServerFQDN,
$DestServerFQDN
)

    Get-CMPackage | Update-PackageSourcePath -SourceServerFQDN $SourceServerFQDN -DestServerFQDN $DestServerFQDN

}