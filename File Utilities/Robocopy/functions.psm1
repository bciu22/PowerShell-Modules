Function Process-RoboCopyOutput
{
Param(
  [Parameter()]
  $RoboCopyOutput
)

  $output = New-Object PSObject 
  $output | Add-Member -MemberType NoteProperty -Name Started -Value $($RoboCopyOutput | Select-String -Pattern '^.*?Started : (.*?)$').Matches.Groups[1].Value
  $output | Add-Member -MemberType NoteProperty -Name Source -Value $($RoboCopyOutput | Select-String -Pattern '^.*?Source : (.*?)$').Matches.Groups[1].Value
  $output | Add-Member -MemberType NoteProperty -Name Dest -Value $($RoboCopyOutput | Select-String -Pattern '^.*?Dest : (.*?)$').Matches.Groups[1].Value
  $output | Add-Member -MemberType NoteProperty -Name Files -Value $($RoboCopyOutput | Select-String -Pattern '^.*?Files : (.*?)$').Matches.Groups[1].Value
  $output | Add-Member -MemberType NoteProperty -Name Options -Value $($RoboCopyOutput | Select-String -Pattern '^.*?Options : (.*?)$').Matches.Groups[1].Value
  $output | Add-Member -MemberType NoteProperty -Name SpeedB -Value $($RoboCopyOutput | Select-String -Pattern '^.*?Speed : (.*?)$').Matches[0].Groups[1].Value
  $output | Add-Member -MemberType NoteProperty -Name SpeedMB -Value $($RoboCopyOutput | Select-String -Pattern '^.*?Speed : (.*?)$').Matches[1].Groups[1].Value
  $output | Add-Member -MemberType NoteProperty -Name Ended -Value $($RoboCopyOutput | Select-String -Pattern '^.*?Ended : (.*?)$').Matches.Groups[1].Value
  $output | Add-Member -MemberType NoteProperty -Name Results -Value $(
    $results = New-Object PSObject
    $results | Add-Member -MemberType NoteProperty -Name Dirs -Value $(Process-ResultLine -ResultLine $RoboCopyOutput -Name Dirs)
    $results | Add-Member -MemberType NoteProperty -Name Files -Value $(Process-ResultLine -ResultLine $RoboCopyOutput -Name Files)
    $results | Add-Member -MemberType NoteProperty -Name Bytes -Value $(Process-ResultLine -ResultLine $RoboCopyOutput -Name Bytes)
    $results | Add-Member -MemberType NoteProperty -Name Times -Value $(Process-ResultLine -ResultLine $RoboCopyOutput -Name Times)
    $results
  )
  $output
}

Function Process-ResultLine
{
Param(
  [Parameter()]
  $ResultLine,
  [Parameter()]
  $Name
)
  $temp = [regex]::Match($ResultLine,'^.*?'+$Name+' :\s+(\d.*?)$').captures.groups[1] -split '\s+'
  $object = New-Object PSObject
  $object | Add-Member -MemberType NoteProperty -Name Total -Value $temp[0]
  $object | Add-Member -MemberType NoteProperty -Name Copied -Value $temp[1]
  $object | Add-Member -MemberType NoteProperty -Name Skipped -Value $temp[2]
  $object | Add-Member -MemberType NoteProperty -Name Mismatch -Value $temp[3]
  $object | Add-Member -MemberType NoteProperty -Name Failed -Value $temp[4]
  $object | Add-Member -MemberType NoteProperty -Name Extras -Value $temp[5]
  $object
}