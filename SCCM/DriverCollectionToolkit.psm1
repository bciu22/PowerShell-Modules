Function Get-IniContent {  
    <#  
    .Synopsis  
        Gets the content of an INI file  
          
    .Description  
        Gets the content of an INI file and returns it as a hashtable  
          
    .Notes  
        Author        : Oliver Lipkau <oliver@lipkau.net>  
        Blog        : http://oliver.lipkau.net/blog/  
        Source        : https://github.com/lipkau/PsIni 
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91 
        Version        : 1.0 - 2010/03/12 - Initial release  
                      1.1 - 2014/12/11 - Typo (Thx SLDR) 
                                         Typo (Thx Dave Stiff) 
          
        #Requires -Version 2.0  
          
    .Inputs  
        System.String  
          
    .Outputs  
        System.Collections.Hashtable  
          
    .Parameter FilePath  
        Specifies the path to the input file.  
          
    .Example  
        $FileContent = Get-IniContent "C:\myinifile.ini"  
        -----------  
        Description  
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent  
      
    .Example  
        $inifilepath | $FileContent = Get-IniContent  
        -----------  
        Description  
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent  
      
    .Example  
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini"  
        C:\PS>$FileContent["Section"]["Key"]  
        -----------  
        Description  
        Returns the key "Key" of the section "Section" from the C:\settings.ini file  
          
    .Link  
        Out-IniFile  
    #>  
      
    [CmdletBinding()]  
    Param(  
        [ValidateNotNullOrEmpty()]  
        [ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".inf")})]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$FilePath  
    )  
      
    Begin  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}  
          
    Process  
    {  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"  
              
        $ini = @{}  
        switch -regex -file $FilePath  
        {  
            "^\[(.+)\]$" # Section  
            {  
                $section = $matches[1]  
                $ini[$section] = @{}  
                $CommentCount = 0  
            }  
            "^(;.*)$" # Comment  
            {  
                if (!($section))  
                {  
                    $section = "No-Section"  
                    $ini[$section] = @{}  
                }  
                $value = $matches[1]  
                $CommentCount = $CommentCount + 1  
                $name = "Comment" + $CommentCount  
                $ini[$section][$name] = $value  
            }   
            "(.+?)\s*=\s*(.*)" # Key  
            {  
                if (!($section))  
                {  
                    $section = "No-Section"  
                    $ini[$section] = @{}  
                }  
                $name,$value = $matches[1..2]  
                $ini[$section][$name] = $value  
            }  
        }  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"  
        Return $ini  
    }  
          
    End  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}  
} 

Function Ensure-Drivers
{
    $naughtyDevices = Get-WmiObject -Class Win32_PnpEntity -ComputerName localhost -Namespace Root\CIMV2 | Where-Object {$_.ConfigManagerErrorCode -gt 0 }

    $objReturn = @()
    ForEach($device in $naughtyDevices)
    {
        $objDevice = [PSCustomObject]@{
            Name = $device.Name
            DeviceID = $device.DeviceID
            ErrorCode = $device.ConfigManagerErrorCode
        }
        $objReturn += $objDevice
    }
    return $objReturn
}

Function Gather-Drivers
{

$InstallDate = [DateTime]$(gcim Win32_OperatingSystem | select InstallDate | Select-Object -ExpandProperty InstallDate)

Get-ChildItem C:\Windows\System32\DriverStore\FileRepository | 
    Where-Object {[DateTime]$($_.CreationTime) -gt $InstallDate} | 
    Foreach-Object {
        $DriverObject = New-Object -TypeName PSCustomObject
        $INFFile = Get-ChildItem $_.FullName -Filter "*.inf"
        if($INFFile.Target)
        {
            if($inffile.target.count -gt 1)
            {
                $Config = Get-IniContent -FilePath $($INFFile.Target[0])
            } 
            else
            {
                $Config = Get-IniContent -FilePath $($INFFile.Target)
            }
           
            Add-Member -InputObject $DriverObject -MemberType NoteProperty -Name "FolderName" -Value $($_.FullName)
            Add-Member -InputObject $DriverObject -MemberType NoteProperty -Name "INFs" -Value $INFFile
            Add-Member -InputObject $DriverObject -MemberType NoteProperty -Name "INFProperties" -Value $Config
            $DriverObject
        }
    }
}


Function Create-CMDriverPackage 
{



}

Function Add-CMDriversToTaskSequence
{



}

Function Get-DeviceModelName
{
    
    $model = $(Get-WmiObject -Class Win32_ComputerSystem | select -ExpandProperty model)
    if ([string]::IsNullOrWhiteSpace($model))
    {
        $model = Get-WmiObject -Class Win32_Baseboard | select -ExpandProperty Product
    }

    $model

}

Function Create-DriverZIPArchive
{
[CmdletBinding()]
Param(  
    [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
    $Driver
)  

    Begin
    {
        Add-Type -Assembly ‘System.IO.Compression.FileSystem’ -PassThru
        $ModelName = Get-DeviceModelName
        If(Test-Path -Path "$($env:TEMP)\DriverArchive\$($ModelName)")
        {
            Remove-Item -Path "$($env:TEMP)\DriverArchive\$($ModelName)" -Recurse -Force
        }
        If(Test-Path -Path "$($env:USERPROFILE)\Desktop\$($ModelName).zip")
        {
            Remove-Item -Path "$($env:USERPROFILE)\Desktop\$($ModelName).zip" -Force
        }
        $NewPath = New-Item -Path "$($env:TEMP)\DriverArchive" -ItemType Directory -Name $ModelName -Force
    }

    Process
    {
        $Driver | fl
        Copy-Item -Path $Driver.FolderName -Destination $NewPath
    }

    End
    {
        [IO.Compression.ZIPFile]::CreateFromDirectory($NewPath, "$($env:USERPROFILE)\Desktop\$($ModelName).zip")
    }
}

Function Export-SystemDrivers
{
<#
    .SYNOPSIS
        Gather all non-default drivers on a system, and package them nicely

    .DESCRIPTION
        Gather all drivers that have been added to a system, and package them for SCCM, PSAppDeployToolkit, Mount to an existing WIM, or just export as a ZIP file
        
        
#>
[CmdletBinding()]
param(
[Switch]
$CreateCMDriverPackages = $false,
[Switch]
$AddToTaskSequences,
[Switch]
$ExportToZIP = $true

)
    #If there are naughty device drivers (missing, etc.) prompt user
    if ($missingDrivers = Ensure-Drivers)
    {
        $missingDrivers | FT
        $input = ""
        While($input -notmatch '[yYnN]')
        {
            $input = Read-Host -Prompt "Missing\Invalid drivers detected, continue (y|n)"
        }
        If($input -ine "y")
        {
            return
        }
    }

    $Drivers = Gather-Drivers | ?{@("Printer","USB","System") -notcontains $_.INFProperties.Version.Class}
    if($ExportToZIP)
    {
        $Drivers | Create-DriverZIPArchive
    }
    if($CreateCMDriverPackages)
    {
        $Drivers | Create-CMDriverPackage
    }
    if($AddToTaskSequences)
    {
        $Drivers | Add-CMDriversToTaskSequence
    }
}