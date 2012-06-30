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

    $test_VIRTUALENVWRAPPER_VIRTUALENV_ExistingValueIsRespected = {
        $VIRTUALENVWRAPPER_VIRTUALENV = "foo"
        import-module "../virtualenvwrapper"

        $VIRTUALENVWRAPPER_VIRTUALENV -eq "foo"

        remove-module "virtualenvwrapper"
    }

    makeTestCase
}

makeTestSuite
