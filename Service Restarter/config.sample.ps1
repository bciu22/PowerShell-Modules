$smtpTo = "servermonitor@somedomain.org"
$cn = gc env:computername;
$smtpFrom = "$cn@somedomain.org"
$smtpServer = "Mail.somedomain.org"