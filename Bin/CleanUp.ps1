$thisPath = split-path $MyInvocation.MyCommand.Path -parent
$projRoot = split-path $thisPath -parent

remove-item -path "$projRoot/*.pyc"
remove-item -path "$projRoot/dist" -recurse