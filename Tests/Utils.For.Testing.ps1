#======================================================================
# Helpers for test suites.
function _MakeFakeVirtualEnvironment {
    param(
        $Name=$(throw "Need a name."),
        $WorkonHome="$env:TEMP/PowerTestTests"
    )

    $path = join-path $WorkonHome "$Name\Scripts\activate.ps1"
    [void] (new-item -itemtype "f" $path -force)
}

function _MakeFakeWorkonHome {
    param($Name="PowerTestTests")
    # todo: Get random file name.
    (new-item -itemtype "d" (join-path "$env:TEMP" $Name) -force)
}

function _RemoveVirtualEnvWrapperEvents {
    unregister-event "virtualenvwrapper.*"
    remove-job -name "virtualenvwrapper.*"
    remove-event "virtualenvwrapper.*"
}
#======================================================================
