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

        [void] (new-event "virtualenvwrapper.Initialize")

        & $logic

        remove-item $newWorkOnHome -recurse -force
    }

    $test_InitializeGlobalHooks = {

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

    $test_InitializeLocalHooks = {
        [void] (new-event "virtualenvwrapper.PreMakeVirtualenv" -eventarguments "xxx")
        $hooks = get-childitem "$env:WORKON_HOME/xxx/Scripts" -filter "*.ps1" | select-object -expandproperty "name"

        $hooks -contains 'VEW_PreActivateVirtualEnv.ps1'
        $hooks -contains 'VEW_PostActivateVirtualEnv.ps1'
        $hooks -contains 'VEW_PreDeactivateVirtualEnv.ps1'
        $hooks -contains 'VEW_PostDeactivateVirtualEnv.ps1'
    }

    $test_PreMakeVirtualeEnv = {
        # runs as subproc
        set-content -path "$env:WORKON_HOME/VEW_PreMakeVirtualEnv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PreMakeVirtualenv")

        (test-path "$env:WORKON_HOME/xxx.out")
        !(test-path env:XXX)
    }

    $test_PostMakeVirtualEnv = {
        # runs as subproc
        set-content -path "$env:WORKON_HOME/VEW_PostMakeVirtualEnv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PostMakeVirtualenv")

        (test-path "$env:WORKON_HOME/xxx.out")
        (test-path env:XXX)
        ($env:XXX -eq "42")

        remove-item env:XXX
    }

    $test_PreRemoveVirtualenv = {
        # runs as subproc
        set-content -path "$env:WORKON_HOME/VEW_PreRemoveVirtualenv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PreRemoveVirtualenv")

        (test-path "$env:WORKON_HOME/xxx.out")
        !(test-path env:XXX)
    }

    $test_PostRemoveVirtualEnv = {
        # runs as subproc
        set-content -path "$env:WORKON_HOME/VEW_PostRemoveVirtualEnv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PostRemoveVirtualEnv")

        (test-path "$env:WORKON_HOME/xxx.out")
        !(test-path env:XXX)
    }


    # Run this test before the previous one or it will never pass.
    $test_PreActivateVirtualEnvLocal = {
        [void] (new-event "virtualenvwrapper.PreMakeVirtualenv" -eventarguments "foo")
        set-content -path "$env:WORKON_HOME/foo/Scripts/VEW_PreActivateVirtualEnv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PreActivateVirtualEnv" -eventarguments "foo")

        (test-path "$env:WORKON_HOME/xxx.out")
        (test-path env:XXX)
        ($env:XXX -eq 42)

        remove-item env:XXX
    }

    # Run this test AFTER the previous one or the previous one will never pass.
    $test_PreActivateVirtualEnvGlobal = {
        # runs as subproc
        set-content -path "$env:WORKON_HOME/VEW_PreActivateVirtualEnv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PreActivateVirtualEnv" -eventarguments "foo")

        (test-path "$env:WORKON_HOME/xxx.out")
        !(test-path env:XXX)
    }

    $test_PostActivateVirtualEnvGlobal ={
        set-content -path "$env:WORKON_HOME/VEW_PostActivateVirtualEnv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PostActivateVirtualEnv" -eventarguments "foo")

        (test-path "$env:WORKON_HOME/xxx.out")
        (test-path env:XXX)

        remove-item env:XXX
    }

    $test_PostActivateVirtualEnvLocal = {
        set-content -path "$env:WORKON_HOME/VEW_PostActivateVirtualEnv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PostActivateVirtualEnv" -eventarguments "foo")

        (test-path "$env:WORKON_HOME/xxx.out")
        (test-path env:XXX)

        remove-item env:XXX
    }

    $test_PreRemoveVirtualEnvGlobal = {
        # runs as subproc
        set-content -path "$env:WORKON_HOME/VEW_PreRemoveVirtualEnv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PreRemoveVirtualEnv" -eventarguments "foo")

        (test-path "$env:WORKON_HOME/xxx.out")
        !(test-path env:XXX)
    }

    $test_PostRemoveVirtualEnvGlobal = {
        # runs as subproc
        set-content -path "$env:WORKON_HOME/VEW_PostRemoveVirtualEnv.ps1" `
                    -value "`$env:XXX = 42; [void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/xxx.out')" `
                    -encoding "utf8"

        [void] (new-event "virtualenvwrapper.PostRemoveVirtualEnv" -eventarguments "foo")

        (test-path "$env:WORKON_HOME/xxx.out")
        !(test-path env:XXX)
    }

    makeTestCase
}

makeTestSuite
