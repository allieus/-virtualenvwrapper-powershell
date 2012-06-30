$setupTestSuite = {
    param($Logic)

    import-module "./../virtualenvwrapper/win.psm1"

    [void] (new-item -itemtype "d" "$env:TEMP/PowerTestTests/FOO/Scripts" -force)
    $targetPath = "$env:TEMP/PowerTestTests/FOO"

    & $Logic

    remove-module "win"
    remove-item "$env:TEMP/PowerTestTests" -recurse
}

$TestCase_AddPoshToVirtualenv = {
    $test_ActivationScriptIsAddedToVirtualenv = {
        [void] (add_posh_to_virtualenv -targetpath $targetPath)

        (test-path "$targetPath/Scripts/activate.ps1")
        (get-content "$targetpath/Scripts/activate.ps1")[0] -eq "# This file must be dot sourced from PoSh; you cannot run it"
    }

    makeTestCase
}

# TODO: Test the rest of the Win.psm1 module!

makeTestSuite
