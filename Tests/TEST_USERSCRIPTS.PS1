$setUpTestSuite = {
    param($logic)

    $_oldWORKON_HOME = $env:WORKON_HOME

    . "./../virtualenvwrapper/extensions/extension.userscripts.ps1"

    & $logic

    unregister-event "virtualenvwrapper.*"
    remove-item function:VEW_RunInSubProcess

    if ($_oldWORKON_HOME) { $env:WORKON_HOME = $_oldWORKON_HOME }
}

$TestCase_Utils = {
    $test_VEW_RunInSubProcessIsDefined = {
        (test-path function:VEW_RunInSubProcess)
    }

    $test_VEW_RunInSubProcessRunsInSeparateProcess = {
        $script = new-item -itemtype "f" "$env:TEMP/FOOSCRIPT.ps1" -force
        set-content -path $script `
                    -value "`$env:XXX = 'HELLO WORLD'; [void] (new-item -itemtype 'f' '$env:TEMP/FOOSCRIPT.OUT')"

        VEW_RunInSubProcess $script

        (test-path "$env:TEMP\FOOSCRIPT.OUT")
        !(test-path env:XXX)

        remove-item "$env:TEMP/FOOSCRIPT.ps1"
        remove-item "$env:TEMP/FOOSCRIPT.OUT"
    }

    makeTestCase
}

$TestCase_EventRegistration = {
    $test_CanRegisterEvents = {
        $allEvents = (get-eventsubscriber "virtualenvwrapper.*") | select-object -expandproperty "SourceIdentifier"

        ($allEvents -eq"virtualenvwrapper.PreMakeVirtualEnv").count -eq 2
        $allEvents -contains "virtualenvwrapper.PostMakeVirtualEnv"
        $allEvents -contains "virtualenvwrapper.PreRemoveVirtualEnv"
        $allEvents -contains "virtualenvwrapper.PostRemoveVirtualEnv"
        ($allEvents -eq "virtualenvwrapper.PreActivateVirtualEnv").count -eq 2
        ($allEvents -eq "virtualenvwrapper.PostActivateVirtualEnv").count -eq 2
        ($allEvents -eq "virtualenvwrapper.PreDeactivateVirtualEnv").count -eq 2
        ($allEvents -eq "virtualenvwrapper.PostDeactivateVirtualEnv").count -eq 2
        $allEvents -contains "virtualenvwrapper.Initialize"
    }

    makeTestCase
}

$TestCase_EventTriggering = {
    $setUpTestCase = {
        param($Logic)
        # fake WORKON_HOME
        $newWorkOnHome = (new-item -itemtype "d" -path "$env:TEMP/PowerTestTests" -force).fullname
        $env:WORKON_HOME = $newWorkOnHome

        & $logic

        remove-item $newWorkOnHome -recurse -force
    }

    $test_Whatever = {
        [void] (new-event "virtualenvwrapper.Initialize")
        start-sleep -seconds 0

        $hooks = get-childitem "$env:WORKON_HOME" -filter "*.ps1" | select-object -expandproperty "name"

        $hooks -contains 'VEW_PreMakeVirtualEnv.ps1'
        $hooks -contains 'VEW_PostMakeVirtualEnv.ps1'
        $hooks -contains 'VEW_PreRemoveVirtualEnv.ps1'
        $hooks -contains 'VEW_PostRemoveVirtualEnv.ps1'
        $hooks -contains 'VEW_PreActivateVirtualEnv.ps1'
        $hooks -contains 'VEW_PostActivateVirtualEnv.ps1'
        $hooks -contains 'VEW_PreDeactivateVirtualEnv.ps1'
        $hooks -contains 'VEW_PostDeactivateVirtualEnv.ps1'
    }

    makeTestCase
}

makeTestSuite
