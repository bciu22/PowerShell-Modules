#----------------------------------------------------------------------------------------------#
# This script is not to be executed directly, but rather used as part of a SQL maintenance job #
#----------------------------------------------------------------------------------------------#

powershell.exe -command "Get-ChildItem -Path 'D:\SCCM SQL Backups\*' -Include '*.zip' | Where-Object {$_.CreationTime -lt (Get-Date).AddDays(-7)} | Remove-Item; Add-Type -Assembly 'System.IO.Compression.FileSystem' -PassThru | Select -First 1 | ForEach-Object { [IO.Compression.ZIPFile]::CreateFromDirectory('c:\program files\microsoft configuration manager\cd.latest', 'D:\SCCM SQL Backups\' + (Get-Date -format 'yyyyMMddHHmm') + '.zip') }"