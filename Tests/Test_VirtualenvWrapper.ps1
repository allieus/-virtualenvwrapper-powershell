$setUpTestSuite = {
    param($logic)

    $_oldWORKON_HOME = $env:WORKON_HOME
    $_oldVIRTUALENVWRAPPER_HOOK_DIR = $VIRTUALENVWRAPPER_HOOK_DIR

    & $logic

    unregister-event "virtualenvwrapper.*"

    remove-item env:WORKON_HOME -erroraction "SilentlyContinue"
    if ($_oldWORKON_HOME) { $env:WORKON_HOME = $_oldWORKON_HOME }
    if ($_oldVIRTUALENVWRAPPER_HOOK_DIR) { $global:VIRTUALENVWRAPPER_HOOK_DIR = $_oldVIRTUALENVWRAPPER_HOOK_DIR }
}

$TestCase_Initialisation = {
    $test_WORKON_HOME_VariableIsSetCorrecly = {
        remove-item env:WORKON_HOME -erroraction "SilentlyContinue"
        import-module "../virtualenvwrapper"

        $env:WORKON_HOME -eq "$HOME/.virtualenvs"

        remove-module "virtualenvwrapper"
    }

    $test_WORKON_HOME_ExistingValueIsRespected = {
        $env:WORKON_HOME = "$env:TEMP"
        import-module "../virtualenvwrapper"

        $env:WORKON_HOME -eq "$env:TEMP"

        remove-module "virtualenvwrapper"
    }

    $test_VIRTUALENVWRAPPER_PYTHON_IsSetCorrectly = {
        remove-item variable:VIRTUALENVWRAPPER_PYTHON
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_PYTHON -eq @(get-command "python.exe")[0].definition

        remove-module "virtualenvwrapper"
    }

    $test_VIRTUALENVWRAPPER_PYTHON_ExistingValueIsRespected = {
        $VIRTUALENVWRAPPER_PYTHON = "foo"
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_PYTHON -eq "foo"

        remove-module "virtualenvwrapper"
    }

    $test_VIRTUALENVWRAPPER_VIRTUALENV_IsSetCorrectly = {
        remove-item variable:VIRTUALENVWRAPPER_VIRTUALENV
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_VIRTUALENV -eq "virtualenv.exe"

        remove-module "virtualenvwrapper"
    }

    $test_VIRTUALENVWRAPPER_VIRTUALENV_ExistingValueIsRespected = {
        $VIRTUALENVWRAPPER_VIRTUALENV = "foo"
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_VIRTUALENV -eq "foo"

        remove-module "virtualenvwrapper"
    }

    $test_VIRTUALENVWRAPPER_LOG_DIR_IsSetCorrectly = {
        remove-item variable:VIRTUALENVWRAPPER_LOG_DIR -erroraction "SilentlyContinue"
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_LOG_DIR -eq $env:WORKON_HOME

        remove-module "virtualenvwrapper"
    }

    $test_VIRTUALENVWRAPPER_LOG_DIR_ExistingValueIsRespected = {
        $VIRTUALENVWRAPPER_LOG_DIR = "foo"
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_LOG_DIR -eq "foo"

        remove-module "virtualenvwrapper"
    }

    makeTestCase
}

$TestCase_Workon = {
    $setUpTestCase = {
        param($Logic)
        [void] (new-item -itemtype "f" "$env:TEMP/PowerTestTests/One/Scripts/activate.ps1" -force)
        [void] (new-item -itemtype "f" "$env:TEMP/PowerTestTests/Two/Scripts/activate.ps1" -force)
        [void] (new-item -itemtype "f" "$env:TEMP/PowerTestTests/Three/Scripts/activate.ps1" -force)

        $env:WORKON_HOME = "$env:TEMP/PowerTestTests"

        & $logic

        remove-item "$env:TEMP/PowerTestTests" -recurse -force
    }

    $test_ShowsEnvsIfNoEnvNameIsPassed = {
        import-module "../virtualenvwrapper"
        $envs = workon

        $envs.length -eq 3

        remove-module "virtualenvwrapper"
    }
    makeTestCase
}

$TestCase_SetVirtualEnvironment = {
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

        remove-module "virtualenvwrapper"
    }

    $test_ActivatingVirtualEnvCallsDeactivateFunctionFirst = {
        [void] (new-item -itemtype "f" -path "$env:TEMP/PowerTestTests/FOO/Scripts/activate.ps1" -force)
        $env:WORKON_HOME = "$env:TEMP/PowerTestTests"
        remove-item variable:VIRTUALENVWRAPPER_HOOK_DIR

        function global:deactivate { $global:bogus = "bogus" }

        import-module "../virtualenvwrapper"
        set-content -value "`$env:hello_world = 'hello world'" `
                    -path "$env:TEMP/PowerTestTests/FOO/Scripts/activate.ps1" `
                    -encoding "utf8"

        set-Virtualenvironment "foo"
        $bogus -eq 'bogus'
        $env:hello_world -eq "hello world"

        remove-item "$env:TEMP/PowerTestTests" -recurse
        remove-module "virtualenvwrapper"
        remove-item function:deactivate
        remove-item variable:bogus
    }

    $test_ActivatingVirtualEnvFiresEvents = {
        [void] (new-item -itemtype "f" -path "$env:TEMP/PowerTestTests/FOO/Scripts/activate.ps1" -force)
        $env:WORKON_HOME = "$env:TEMP/PowerTestTests"
        $VIRTUALENVWRAPPER_HOOK_DIR = $env:WORKON_HOME

        import-module "../virtualenvwrapper"

        unregister-event "virtualenvwrapper.*"
        set-Virtualenvironment "foo"

        (get-event -sourceidentifier "Virtualenvwrapper.PreActivateVirtualEnv").count -gt 0
        (get-event -sourceidentifier "Virtualenvwrapper.PostActivateVirtualEnv").count -gt 0

        remove-item "$env:TEMP/PowerTestTests" -recurse
        remove-module "virtualenvwrapper"
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
        [void] (new-item -itemtype "f" -path "$env:TEMP/PowerTestTests/FOO/Scripts/activate.ps1" -force)
        $env:WORKON_HOME = "$env:TEMP/PowerTestTests"
        $VIRTUALENVWRAPPER_HOOK_DIR = $env:WORKON_HOME
        import-module "../virtualenvwrapper"

        register-engineevent -sourceidentifier "virtualenvwrapper.PreActivateVirtualEnv" -action { new-item -itemtype "f" "$env:WORKON_HOME/xxx.txt" }
        register-engineevent -sourceidentifier "virtualenvwrapper.PostActivateVirtualEnv" -action { new-item -itemtype "f" "$env:WORKON_HOME/yyy.txt" }
        set-Virtualenvironment "foo"

        (test-path "$env:WORKON_HOME/xxx.txt")
        (test-path "$env:WORKON_HOME/yyy.txt")

        (get-item "$env:WORKON_HOME/xxx.txt").creationtime -lt (get-item "$env:WORKON_HOME/yyy.txt").creationtime

        remove-item "$env:TEMP/PowerTestTests" -recurse
        remove-module "virtualenvwrapper"
    }

    makeTestCase
}


$TestCase_MakeVirtualenv = {
    $test_CanMakeVirtualenv = {
        # todo: test we can create a virtual environment
    }
    makeTestCase
}

makeTestSuite
