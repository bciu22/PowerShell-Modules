#Share Config
$SourceShares = "SMB-1", "SMB-2"
$Target = "someotherserver.somedomain.org\Archive`$"

#User Config
$secpasswd = ConvertTo-SecureString "SomePassword" -AsPlainText -Force
$SourceShareCredential = New-Object System.Management.Automation.PSCredential ( "WORKGROUP\SomeUser", $secpasswd)

#Robocopy Config
$RobocopyParams = "/MIR" 
$RobocopyLogParams = "/NP"
$RobocopyLogDir = "E:/Archive\"

$smtpTo = "servermonitor@somedomain.org"
$cn = gc env:computername;
$smtpFrom = "$cn@somedomain.org"
$smtpServer = "Mail.somedomain.org"

$mailHead = @"
<style>
BODY{background-color:peachpuff;}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:thistle}
TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:PaleGoldenrod}
</style>
"@
