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