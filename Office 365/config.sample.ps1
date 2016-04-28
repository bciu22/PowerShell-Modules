$UserName='o365admin@somedomain.org'
$Password='somepassword'
$StudentOU = "OU=Students,DC=SomeDomain,DC=org"
$FacultyLicense = "somedomain:STANDARDWOFFPACK_IW_FACULTY"
$StudentLicense = "somedomain:STANDARDWOFFPACK_IW_STUDENT"
#Initialize an empty array, in the event this needs to contain multiple SKUs
$DisabledPlans = @()
#Add plans to disable
$DisabledPlans += "EXCHANGE_S_STANDARD"
$smtpTo = "servermonitor@somedomain.org"
$cn = gc env:computername;
$smtpFrom = "$cn@somedomain.org"
$smtpServer = "Mail.somedomain.org"
#Set UsageLocation
$UsageLocation = "US"
$mailHead = @"
<style>
BODY{background-color:peachpuff;}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:thistle}
TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:PaleGoldenrod}
</style>
"@