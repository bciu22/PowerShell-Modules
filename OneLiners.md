# One Liners

* Rename files containing invalid characters

> Get-ChildItem -Recurse | ?{$_.name -like "*#*"} | Rename-Item -NewName {$_.Name -replace "#"," "}
