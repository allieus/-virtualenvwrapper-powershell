$setUpTestSuite = {
    param($logic)

    . "./Utils.For.Testing.ps1"

    $_oldWORKON_HOME = $env:WORKON_HOME
    $_oldVIRTUALENVWRAPPER_HOOK_DIR = $VIRTUALENVWRAPPER_HOOK_DIR
    $_oldVirtualEnvWrapperVirtualeEnv = $VIRTUALENVWRAPPER_VIRTUALENV

    import-module "./../virtualenvwrapper/support.psm1"

    & $logic

    get-module | remove-module
    _RemoveVirtualEnvWrapperEvents

    remove-item env:WORKON_HOME -erroraction "SilentlyContinue"
    remove-item variable:VIRTUALENVWRAPPER_HOOK_DIR -erroraction "SilentlyContinue"
    if ($_oldWORKON_HOME) { $env:WORKON_HOME = $_oldWORKON_HOME }
    if ($_oldVirtualEnvWrapperVirtualeEnv) { $global:VIRTUALENVWRAPPER_VIRTUALENV = $_oldVirtualEnvWrapperVirtualeEnv }
    if ($_oldVIRTUALENVWRAPPER_HOOK_DIR) { $global:VIRTUALENVWRAPPER_HOOK_DIR = $_oldVIRTUALENVWRAPPER_HOOK_DIR }
}

$TestCase_VerifyFunctions = {
    $test_VerifyVirtualEnvWrapperVirtualEnvFailsWhenVariableNotDefined =  {
        remove-item variable:VIRTUALENVWRAPPER_VIRTUALENV -erroraction "SilentlyContinue"
        try {
            VerifyVirtualEnv
            $false
        }
        catch {
            if ($_.Exception.message -eq "`$VIRTUALENVWRAPPER_VIRTUALENV is not defined.") {
                $true
            }
            else {
                $false
            }
        }
    }

    $test_VerifiyVirtualenvFailsWhenVirtualEnvIsNotFound = {
        $global:VIRTUALENVWRAPPER_VIRTUALENV = "xyz.zyx"
        try {
            VerifyVirtualEnv
            $false
        }
        catch [system.io.filenotfoundexception] {
            $_.exception.message -eq "ERROR: virtualenvwrapper could not find virtualenv in your PATH."
        }
    }

    $test_VerifiyVirtualenvFailsWhenVirtualEnvIsNotFound = {
        $global:VIRTUALENVWRAPPER_VIRTUALENV = "xyz.zyx"
        try {
            VerifyVirtualEnv
            $false
        }
        catch [system.io.filenotfoundexception] {
            $_.exception.message -eq "ERROR: virtualenvwrapper could not find virtualenv in your PATH."
        }
    }

    $test_VerifiyWorkonHomeThrowsErrorWhenNotDefined = {
        [void] (remove-item env:WORKON_HOME)

        try {
            [void] (VerifyWorkonHome)
            $false
        }
        catch [io.directorynotfoundexception]{
            $true
        }
    }

    $test_VerifiyWorkonHomeThrowsErrorWhenSetToBadDirectory = {
        $env:WORKON_HOME = "XYZ:"

        try {
            [void] (VerifyWorkonHome)
            $false
        }
        catch [io.directorynotfoundexception]{
            $true
        }
    }

    $test_VerifyActiveEnvironmentFailsWithInexistingPath = {
        $env:VIRTUAL_ENV = "XYZ:"

        try {
            [void] (VerifyActiveEnvironment)
            $false
        }
        catch [system.io.ioexception] {
            $true
        }
    }

    $test_VerifyActiveEnvironmentFailsIfVirtualEnvEnvironmentVariableIsNotSet = {
        remove-item env:VIRTUAL_ENV -erroraction "SilentlyContinue"

        try {
            [void] (VerifyActiveEnvironment)
            $false
        }
        catch [system.io.ioexception] {
            $true
        }
    }

    $test_VerifiyWorkonHomeWorksFine = {
        $env:WORKON_HOME = "."

        try {
            [void] (VerifyWorkonHome)
            $true
        }
        catch [io.directorynotfoundexception]{
           $false
        }
    }
    makeTestCase
}

$TestCase_LooksLikeAVirtualEnv = {
    $setUpTestCase = {
        param($Logic)

        $fakeWorkonHome = _MakeFakeWorkonHome "PowerTestTests"
        _MakeFakeVirtualEnvironment -Name "FOO" -WorkonHome $fakeWorkonHome
        _MakeFakeVirtualEnvironment -Name "BAR" -WorkonHome $fakeWorkonHome
        $env:WORKON_HOME = $fakeWorkonHome
        remove-item "$fakeWorkonHome/BAR/Scripts/activate.ps1"

        & $Logic

        remove-item $fakeWorkonHome -recurse
    }

    $test_SucceedsWhenItsSupposedTo = {
         $path = (get-item "$env:WORKON_HOME/FOO" | LooksLikeAVirtualenv)
         $path.fullname -eq (get-item "$env:WORKON_HOME/FOO").fullname
    }

    $test_FailWhenItsSupposedTo = {
         $path = (get-item "$env:WORKON_HOME/BAR" | LooksLikeAVirtualenv)
         $path -eq $null
    }

    makeTestCase
}


$TestCase_GetVirtualEnvData = {
    $setUpTestCase = {
        param($Logic)

        $fakeWorkonHome = _MakeFakeWorkonHome "PowerTestTests"
        _MakeFakeVirtualEnvironment -Name "FOO" -WorkonHome $fakeWorkonHome
        _MakeFakeVirtualEnvironment -Name "BAR" -WorkonHome $fakeWorkonHome
        $env:WORKON_HOME = $fakeWorkonHome
        remove-item "$fakeWorkonHome/BAR/Scripts/activate.ps1"

        & $Logic

        remove-item $fakeWorkonHome -recurse
    }

    $test_SucceedsWhenItsSupposedTo = {
         $venvs = @(GetVirtualEnvData)
         $venvs.length -eq 1
         $venvs[0].name -eq "FOO"
    }

    makeTestCase
}


$TestCase_NewVirtualEnvData = {
    $setUpTestCase = {
        param($Logic)

        $fakeWorkonHome = _MakeFakeWorkonHome "PowerTestTests"
        _MakeFakeVirtualEnvironment -Name "FOO" -WorkonHome $fakeWorkonHome
        _MakeFakeVirtualEnvironment -Name "BAR" -WorkonHome $fakeWorkonHome
        $env:WORKON_HOME = $fakeWorkonHome
        remove-item "$fakeWorkonHome/BAR/Scripts/activate.ps1"
        $target_3 = "$env:TEMP/VirtualenvWrapperTests/FOO/lib/site-packages"
        [void] (new-item -itemtype "d" -path $target_3 -force)

        & $Logic

        remove-item $fakeWorkonHome -recurse
    }

    $test_ProduceData = {
        $data = NewVirtualEnvData "$env:TEMP/VirtualenvWrapperTests/FOO"

        $data.name -eq "foo"
        (resolve-path $data.pathtoscripts).providerpath -eq (get-item (join-path "$env:TEMP/VirtualenvWrapperTests/foo" "scripts")).fullname
        (resolve-path $data.pathtositepackages).providerpath -eq (get-item (join-path "$env:TEMP/VirtualenvWrapperTests/foo" "lib/site-packages")).fullname
    }

    makeTestCase
}


$TestCase_Initialize = {
    $setUpTestCase = {
        param($Logic)

        $fakeWorkonHome = _MakeFakeWorkonHome "VirtualenvWrapperTests"
        remove-item alias:cdproject -erroraction "SilentlyContinue"
        remove-item alias:mkproject -erroraction "SilentlyContinue"
        remove-item alias:setvirtualenvproject -erroraction "SilentlyContinue"

        Initialize
        & $Logic

        remove-item $fakeWorkonHome
    }

    $test_Initialize = {
        $events = get-event "VirtualenvWrapper.*"
        @($events).count -eq 1
    }

    $test_ThatExtensionsAreLoaded = {
        # Virtualenvwrapper will load extenions when Initialize runs. Test
        # that it is so.
        test-path alias:mkproject
        test-path alias:cdproject
    }

    makeTestCase
}

makeTestSuite
