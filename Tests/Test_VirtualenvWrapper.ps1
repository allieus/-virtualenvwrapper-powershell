$setUpTestSuite = {
    param($logic)

    #==========================================================================
    # Helpers for test suites.
    . "./Utils.For.Testing.ps1"
    #==========================================================================

    $_oldWORKON_HOME = $env:WORKON_HOME
    $_oldVIRTUALENVWRAPPER_HOOK_DIR = $VIRTUALENVWRAPPER_HOOK_DIR
    $_oldVIRTUALENVWRAPPER_LOG_DIR = $VIRTUALENVWRAPPER_LOG_DIR

    try {
        & $logic
    }
    finally {
        _RemoveVirtualEnvWrapperEvents
        get-module | remove-module

        if ($_oldWORKON_HOME) { $env:WORKON_HOME = $_oldWORKON_HOME }
        if ($_oldVIRTUALENVWRAPPER_HOOK_DIR) { $global:VIRTUALENVWRAPPER_HOOK_DIR = $_oldVIRTUALENVWRAPPER_HOOK_DIR }
        if ($_oldVIRTUALENVWRAPPER_LOG_DIR) { $global:VIRTUALENVWRAPPER_LOG_DIR = $_oldVIRTUALENVWRAPPER_LOG_DIR }
    }
}

$TestCase_Initialisation = {
    $setUpTestCase = {
        param($Logic)

        & $Logic

        get-module | remove-module
    }

    $test_WORKON_HOME_VariableIsSetCorrecly = {
        remove-item env:WORKON_HOME -erroraction "SilentlyContinue"
        import-module "../virtualenvwrapper"

        $env:WORKON_HOME -eq "$HOME/.virtualenvs"
    }

    $test_WORKON_HOME_ExistingValueIsRespected = {
        $env:WORKON_HOME = "$env:TEMP"
        import-module "../virtualenvwrapper"

        $env:WORKON_HOME -eq "$env:TEMP"
    }

    $test_VIRTUALENVWRAPPER_PYTHON_IsSetCorrectly = {
        remove-item variable:VIRTUALENVWRAPPER_PYTHON
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_PYTHON -eq @(get-command "python.exe")[0].definition
    }

    $test_VIRTUALENVWRAPPER_PYTHON_ExistingValueIsRespected = {
        $VIRTUALENVWRAPPER_PYTHON = "foo"
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_PYTHON -eq "foo"
    }

    $test_VIRTUALENVWRAPPER_VIRTUALENV_IsSetCorrectly = {
        remove-item variable:VIRTUALENVWRAPPER_VIRTUALENV
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_VIRTUALENV -eq "virtualenv.exe"
    }

    $test_VIRTUALENVWRAPPER_VIRTUALENV_ExistingValueIsRespected = {
        $VIRTUALENVWRAPPER_VIRTUALENV = "foo"
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_VIRTUALENV -eq "foo"
    }

    $test_VIRTUALENVWRAPPER_LOG_DIR_IsSetCorrectly = {
        remove-item variable:VIRTUALENVWRAPPER_LOG_DIR -erroraction "SilentlyContinue"
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_LOG_DIR -eq $env:WORKON_HOME
    }

    $test_VIRTUALENVWRAPPER_LOG_DIR_ExistingValueIsRespected = {
        $VIRTUALENVWRAPPER_LOG_DIR = "foo"
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_LOG_DIR -eq "foo"
    }

    makeTestCase
}

$TestCase_Workon = {
    $setUpTestCase = {
        param($Logic)

        $fakeWorkonHome = (_MakeFakeWorkonHome -Name "PowerTestTests")
        $env:WORKON_HOME = $fakeWorkonHome.fullname
        _MakeFakeVirtualEnvironment -Name "One" -WorkonHome "$env:WORKON_HOME"
        _MakeFakeVirtualEnvironment -Name "Two" -WorkonHome "$env:WORKON_HOME"
        _MakeFakeVirtualEnvironment -Name "Three" -WorkonHome "$env:WORKON_HOME"

        import-module "../virtualenvwrapper"

        & $logic

        remove-item $fakeWorkonHome -recurse -force
        get-module | remove-module
    }

    $test_ShowsEnvsIfNoEnvNameIsPassed = {
        $envs = workon
        $envs.length -eq 3
    }

    makeTestCase
}

$TestCase_SetVirtualEnvironment = {
    $setUpTestCase = {
        param($Logic)

        $fakeWorkonHome = _MakeFakeWorkonHome "PowerTestTests"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -name "FOO"
        $env:WORKON_HOME = $fakeWorkonHome
        $VIRTUALENVWRAPPER_HOOK_DIR = $env:WORKON_HOME

        & $Logic

        _RemoveVirtualEnvWrapperEvents
        remove-item $fakeWorkonHome -recurse
    }

    $test_FailsIfNoVenvNameIsPassed = {
        import-module "../virtualenvwrapper"

        try {
            [void] (set-Virtualenvironment)
            $false
        }
        catch {
            if ($_.Exception.Message -eq "You must specify a virtual environment name.") {
                $true
            }
            else {
                $false
            }
        }
    }

    $test_ActivatingVirtualEnvCallsDeactivateFunctionFirst = {
        remove-item variable:VIRTUALENVWRAPPER_HOOK_DIR

        function global:deactivate { $global:bogus = "bogus" }

        import-module "../virtualenvwrapper"
        _RemoveVirtualEnvWrapperEvents

        set-content -value "`$env:hello_world = 'hello world'" `
                    -path "$env:TEMP/PowerTestTests/FOO/Scripts/activate.ps1" `
                    -encoding "utf8"

        set-Virtualenvironment "foo"

        $bogus -eq 'bogus'
        $env:hello_world -eq "hello world"

        remove-item function:deactivate
        remove-item variable:bogus
    }

    $test_ActivatingVirtualEnvFiresEvents = {
        # todo: this test fails intermitently
        import-module "../virtualenvwrapper"
        _RemoveVirtualEnvWrapperEvents

        [void] (set-Virtualenvironment "foo")

        @(get-event -sourceidentifier "Virtualenvwrapper.PreActivateVirtualEnv").count -eq 1
        @(get-event -sourceidentifier "Virtualenvwrapper.PostActivateVirtualEnv").count -eq 1
    }

    $test_ActivatingVirtualEnvFailsIfThereAreAnyProblems = {
        $env:WORKON_HOME = ""
        import-module "../virtualenvwrapper"

        try {
            set-Virtualenvironment "foo"
            $false
        }
        catch [system.io.ioexception] {
            $true
        }

        remove-module "virtualenvwrapper"
    }

    $test_ActivationEventsRunInOrder = {
        # todo: remove event subscribers from environment before testing this
        import-module "../virtualenvwrapper"
        _RemoveVirtualEnvWrapperEvents

        register-engineevent -sourceidentifier "virtualenvwrapper.PreActivateVirtualEnv" -action { new-item -itemtype "f" "$env:WORKON_HOME/xxx.txt" }
        register-engineevent -sourceidentifier "virtualenvwrapper.PostActivateVirtualEnv" -action { new-item -itemtype "f" "$env:WORKON_HOME/yyy.txt" }
        set-Virtualenvironment "foo"

        (test-path "$env:WORKON_HOME/xxx.txt")
        (test-path "$env:WORKON_HOME/yyy.txt")

        (get-item "$env:WORKON_HOME/xxx.txt").creationtime -lt (get-item "$env:WORKON_HOME/yyy.txt").creationtime
    }

    makeTestCase
}

$TestCase_MakeVirtualenv = {
    $setUpTestCase = {
        param($Logic)
        $fakeWorkonHome = _MakeFakeWorkonHome
        $env:WORKON_HOME = $fakeWorkonHome
        $VIRTUALENVWRAPPER_HOOK_DIR = $env:WORKON_HOME

        & $Logic

        remove-item $fakeWorkonHome -recurse
        get-module | remove-module
    }

    $test_CanMakeVirtualenv = {
        [void] (import-module "../virtualenvwrapper")
        # Due to async issues, if we don't unregister events, VIRTUALENVWRAPPER_HOOK_DIR
        # will have been reset to the original one by the time some events trigger. This is not
        # what we want during testing.
        _RemoveVirtualEnvWrapperEvents

        [void] (new-virtualenvironment "foo")

        test-path function:deactivate

        [void] (deactivate)

        test-path "$env:WORKON_HOME/foo"
    }
    makeTestCase
}

makeTestSuite
