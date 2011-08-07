$thisPath = split-path $MyInvocation.MyCommand.Path -parent
$projRoot = split-path $thisPath -parent
$script:pathToProfile = split-path $profile -parent
$script:pathToUserModules = "$pathToProfile/Modules"

copy-item "$projRoot/virtualenvwrapper" -dest $pathToUserModules -recurse -force -erroraction silentlycontinue
if (-not $?) { write-host -fore red "Error."; break }

write-host "virtualenvwrapper: Installation complete." -fore darkgreen
write-host "Import module to start using it: Import-Module VirtualEnvWrapper"