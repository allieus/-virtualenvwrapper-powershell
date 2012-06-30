$setUpTestSuite = {
    param($logic)

    $_oldWORKON_HOME = $env:WORKON_HOME
    $_oldVIRTUALENVWRAPPER_HOOK_DIR = $VIRTUALENVWRAPPER_HOOK_DIR

    import-module "./../virtualenvwrapper"

    & $logic

    remove-module "virtualenvwrapper"

    unregister-event "virtualenvwrapper.*"
    remove-item function:VEW_RunInSubProcess

    remove-item env:WORKON_HOME -erroraction "SilentlyContinue"
    remove-item variable:VIRTUALENVWRAPPER_HOOK_DIR -erroraction "SilentlyContinue"
    if ($_oldWORKON_HOME) { $env:WORKON_HOME = $_oldWORKON_HOME }
    if ($_oldVIRTUALENVWRAPPER_HOOK_DIR) { $global:VIRTUALENVWRAPPER_HOOK_DIR = $_oldVIRTUALENVWRAPPER_HOOK_DIR }
}

$TestCase_Foo = {
    $test_foo = {
        1 -eq 2
    }

    makeTestCase
}

makeTestSuite
