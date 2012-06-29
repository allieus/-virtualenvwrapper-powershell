$setUpTestSuite = {
    param($logic)

    $_oldWORKON_HOME = $env:WORKON_HOME
    $_oldVirtualEnvWrapperHookDir = $VirtualenvWrapperHookDir

    import-module "./../virtualenvwrapper/virtualenvwrapper.psm1"

    & $logic

    remove-module "virtualenvwrapper"

    unregister-event "virtualenvwrapper.*"
    remove-item function:VEW_RunInSubProcess

    remove-item env:WORKON_HOME -erroraction "SilentlyContinue"
    remove-item variable:VirtualenvWrapperHookDir -erroraction "SilentlyContinue"
    if ($_oldWORKON_HOME) { $env:WORKON_HOME = $_oldWORKON_HOME }
    if ($_oldVirtualEnvWrapperHookDir) { $global:VirtualEnvWrapperHookDir = $_oldVirtualEnvWrapperHookDir }
}

$TestCase_Foo = {
    $test_foo = {
        1 -eq 2
    }

    makeTestCase
}

makeTestSuite
