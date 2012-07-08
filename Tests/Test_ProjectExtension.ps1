$setUpTestSuite = {
    param($logic)

    . ".\Utils.For.Testing.ps1"

    $_oldVirtualEnv = $env:VIRTUAL_ENV
    $_oldWORKON_HOME = $env:WORKON_HOME
    if (test-path variable:ProjectHome) { $_oldProjectHome = $global:ProjectHome }

    . "./../virtualenvwrapper/extensions/extension.project.ps1"

    $INVALID_DIRNAME = "\:"

    & $logic

    remove-item alias:cdproject
    remove-item alias:mkproject
    remove-item alias:setvirtualenvproject
    _RemoveVirtualEnvWrapperEvents

    $env:VIRTUAL_ENV = $_oldVirtualEnv
    $env:WORKON_HOME = $_oldWORKON_HOME
    if ($_oldProjectHome) { $global:ProjectHome = $_oldProjectHome }
    else { [void] (remove-item variable:ProjectHome -erroraction "SilentlyContinue") }
}

$TestCase_AreAliasAvailable = {
    $test_CdProjectAliasExists = {
        test-path alias:cdproject
        $alias = get-item alias:cdproject
        "$($alias.definition)" -eq "Set-LocationToProject"
    }

    $test_MkProjectAliasExists = {(test-path alias:mkproject)}
    $test_MkSetVirtualEnvProjectAliasExists = {(test-path alias:setvirtualenvproject)}

    makeTestCase
}

$TestCase_AreEventSubscribersRegistered = {
    $test_ExtensionOwnEvents = {
        $events = (get-eventsubscriber "virtualenvwrapper.project.*") | sort-object -property "sourceidentifier"
        $events[0].sourceidentifier -eq "virtualenvwrapper.project.postmakevirtualenvproject"
        $events[1].sourceidentifier -eq "virtualenvwrapper.project.premakevirtualenvproject"
    }

    $test_InitializeEvent = {
        $action = get-eventsubscriber "virtualenvwrapper.initialize" | select-object -expandproperty "action"
        $action.command.tostring() -match "VEW_PreMakeProject\.ps1"
        $action.command.tostring() -match "VEW_PostMakeProject\.ps1"
    }

    makeTestCase
}

$TestCase_VerifyProjectHome = {
    $test_ProjectHomeVariableIsNotDefined = {
        try {
            [void] (remove-item variable:ProjectHome -erroraction "SilentlyContinue")
            VEW_Project_VerifyProjectHome
        }
        catch {
            $_.Exception.Message -eq "You must set the `$ProjectHome variable to point to a directory."
        }
    }

    $test_ProjectHomePointsToInvalidDirectory = {
        try {
            $ProjectHome = $INVALID_DIRNAME
            VEW_Project_VerifyProjectHome
        }
        catch {
            $_.Exception.Message -eq "Set `$ProjectHome to an existing directory."
        }
    }

    makeTestCase
}

$TestCase_SetVirtualEnvProject = {
    $setUpTestCase = {
        param($Logic)

        $fakeWorkonHome = _MakeFakeWorkonHome "PowerTestTests"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -Name "FOO"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -Name "BAR"
        $newProjectsHome = "$fakeWorkonHome/PROJECTS"
        [void] (new-item -itemtype "d" -path $newProjectsHome -force)

        $ProjectHome = $newProjectsHome
        $env:WORKON_HOME = $fakeWorkonHome

        & $Logic

        remove-item -path $fakeWorkonHome -recurse
    }

    $test_PassingANamedVirtualenv = {
        [void] (set-virtualenvproject -venv "$env:WORKON_HOME/FOO" `
                                      -Project "$env:WORKON_HOME/BAR")
        test-path "$env:WORKON_HOME/FOO/.project"
        (get-content "$env:WORKON_HOME/FOO/.project") -eq "$env:WORKON_HOME/BAR"
    }

    $test_NoNamedVirtualenv = {
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/FOO"
        [void] (set-virtualenvproject -Project "$env:WORKON_HOME/BAR")
        test-path "$env:WORKON_HOME/FOO/.project"
        (get-content "$env:WORKON_HOME/FOO/.project") -eq "$env:WORKON_HOME/BAR"

    }

    $test_NoNamedProjectOrVirtualenv = {
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/FOO"
        [void] (set-virtualenvproject)
        test-path "$env:WORKON_HOME/FOO/.project"
        (get-content "$env:WORKON_HOME/FOO/.project") -eq (get-location).providerpath

    }

    $test_CantFindVirtualenv = {
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/XXX"
        try {
            [void] (set-virtualenvproject)
        }
        catch {
            $_.exception.message -eq "Can't find virtualenv."
        }

        -not (test-path "$env:WORKON_HOME/XXX/.project")
    }

    $test_CantFindProjectDirectory = {
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/FOO"
        try {
            [void] (set-virtualenvproject -project "$env:WORKON_HOME/XXX")
            $false
        }
        catch {
            $_.exception.message -eq "Can't find project directory."
            $true
        }

        -not (test-path "$env:WORKON_HOME/FOO/.project")
    }

    makeTestCase
}

$TestCase_SetLocationToProeject = {
    $setUpTestCase = {
        param($Logic)

        $fakeWorkonHome = _MakeFakeWorkonHome "PowerTestTests"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -Name "FOO"
        $newProjectsHome = "$fakeWorkonHome/PROJECTS"
        [void] (new-item -itemtype "d" -path $newProjectsHome -force)
        [void] (new-item -itemtype "d" -path "$newProjectsHome/BAR" -force)

        [void] (new-item -itemtype "f" -path "$fakeWorkonHome/FOO/.project" -force)
        "$newProjectsHome/BAR" | out-file -filepath "$fakeWorkonHome/FOO/.project" -encoding "utf8"

        # redefine these two function so they are accessible in this scope without
        # loading virtualenvwrapper-powershell.
        function VerifyWorkonHome { $true }
        function VerifyVirtualEnv { $true }


        $ProjectHome = $newProjectsHome
        $env:WORKON_HOME = $fakeWorkonHome
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/FOO"

        & $Logic

        remove-item -path $fakeWorkonHome -recurse
    }

    $test_ProjectFileDoesNotExist = {
        [void] (remove-item "$env:WORKON_HOME/FOO/.project")
        try{
            Set-LocationToProject
            $false
        }
        catch {
            $_.exception.message -eq "No project set in $env:VIRTUAL_ENV/.project"
            $true
        }
    }

    $test_ProjectDirectoryDoesNotExist = {
        $projDir = "xzy:"
        [void] (set-content -path "$env:WORKON_HOME/FOO/.project" -value $projDir -encoding "utf8")
        try{
            [void] (Set-LocationToProject)
            $false
        }
        catch {
            $_.exception.message -eq "Project directory $projDir does not exist."
            $true
        }
    }

    $test_CanChangeCurrentDirectory = {
        $cwd = get-location
        try {
            [void] (Set-LocationToProject)
            (get-item "$ProjectHome/BAR").path -eq (get-item (get-location)).path
        }
        finally {
            [void] (set-location $cwd)
        }
    }

    makeTestCase
}

$TestCase_NewVirtualEnvProject = {
    $setUpTestCase = {
        param($Logic)

        $oldLocation = get-location

        $fakeWorkonHome = _MakeFakeWorkonHome "PowerTestTests"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -Name "FOO"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -Name "BAR"
        $newProjectsHome = "$fakeWorkonHome/PROJECTS"
        [void] (new-item -itemtype "d" -path $newProjectsHome -force)
        [void] (new-item -itemtype "d" -path "$newProjectsHome/BAR" -force)

        [void] (new-item -itemtype "f" -path "$fakeWorkonHome/FOO/.project" -force)
        "$newProjectsHome/BAR" | out-file -filepath "$fakeWorkonHome/FOO/.project" -encoding "utf8"

        # redefine these two function so they are accessible in this scope without
        # loading virtualenvwrapper-powershell.
        function New-VirtualEnvironment { $true }

        $ProjectHome = $newProjectsHome
        $env:WORKON_HOME = $fakeWorkonHome
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/FOO"

        & $Logic

        set-location $oldLocation
        remove-item -path $fakeWorkonHome -recurse
    }

    $test_StopIfProjectHomeIsNotCorrectlySet = {

        try {
            remove-item variable:ProjectHome
            [void] (new-virtualenvproject -envname "xxx")
            $false
        }
        catch {
            $true # signal this is fine
        }

        $ProjectHome = "xyz:"
        try {
            [void] (new-virtualenvproject -envname "xxx")
            $false
        }
        catch {
            $true # signal this is fine
        }
    }

    $test_StopIfProjectExistsAlready = {
        try {
            [void] (new-virtualenvproject -envname "BAR")
        }
        catch {
            $_.exception.message -eq "Project BAR already exists."
        }
    }

    $test_StopIfNoEnvNameIsProvided = {
        try {
            [void] (new-virtualenvproject)
        }
        catch {
            $_.exception.message -eq "Need a name for the virtual environment."
        }
    }

    $test_StopIfVirtualenvCreationThrowsError = {
        function New-VirtualEnvironment { throw ("bummer!")}
        try {
            [void] (new-virtualenvproject -envname "XXX")
        }
        catch {
            $_.exception.message -eq "bummer!"
        }
    }

    $test_CanCreateNewProject = {
        # fake a new virtual environment
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/NEWPROJECT"
        [void] (new-item -itemtype "d" "$env:WORKON_HOME/NEWPROJECT")

        [void] (new-virtualenvproject -envname "NEWPROJECT")

        (test-path "$ProjectHome/NEWPROJECT")
        (test-path "$env:VIRTUAL_ENV/.project")
        (get-content "$env:VIRTUAL_ENV/.project") -eq "$newProjectsHome/NEWPROJECT"
    }

    makeTestCase
}

$TestCase_ProjectEventsTriggering = {
    $setUpTestCase = {
        param($Logic)

        # we need this because it should be exported by virtualenvwrapper and
        # we are not sourcing that namespace here.
        function global:VEW_RunInSubProcess {
            param($Script)

            start-process 'powershell.exe' `
                                       -NoNewWindow `
                                       -Wait `
                                        -ArgumentList '-Nologo', `
                                             '-NoProfile', `
                                             # Between quotes so that paths with spaces work.
                                             '-File', "`"$Script`""
        }

        $oldLocation = get-location

        $fakeWorkonHome = _MakeFakeWorkonHome "PowerTestTests"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -Name "FOO"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -Name "BAR"
        $newProjectsHome = "$fakeWorkonHome/PROJECTS"
        [void] (new-item -itemtype "d" -path $newProjectsHome -force)
        [void] (new-item -itemtype "d" -path "$newProjectsHome/BAR" -force)

        [void] (new-item -itemtype "f" -path "$fakeWorkonHome/FOO/.project" -force)
        "$newProjectsHome/BAR" | out-file -filepath "$fakeWorkonHome/FOO/.project" -encoding "utf8"

        # redefine these two function so they are accessible in this scope without
        # loading virtualenvwrapper-powershell.
        function New-VirtualEnvironment { $true }

        $ProjectHome = $newProjectsHome
        $env:WORKON_HOME = $fakeWorkonHome
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/FOO"

        & $Logic

        set-location $oldLocation
        remove-item -path $fakeWorkonHome -recurse
        remove-item function:VEW_RunInSubProcess
    }

    $test_InitializeEvent = {
        new-event "virtualenvwrapper.initialize"
        # were scripts created?

        (test-path "$env:WORKON_HOME/VEW_PreMakeProject.ps1")
        (test-path "$env:WORKON_HOME/VEW_PostMakeProject.ps1")
    }

    $test_PreMakeProject = {
        "[void] (new-item -type 'f' -path '$env:WORKON_HOME/xxx.out')"  | out-file -filepath "$env:WORKON_HOME/VEW_PreMakeProject.ps1" -encoding "utf8"
        [void] (new-event "virtualenvwrapper.project.premakevirtualenvproject")
        (test-path "$env:WORKON_HOME/xxx.out")
    }

    $test_PostMakeProject = {
        "[void] (new-item -type 'f' -path '$env:WORKON_HOME/xxx.out')"  | out-file -filepath "$env:WORKON_HOME/VEW_PostMakeProject.ps1" -encoding "utf8"
        [void] (new-event "virtualenvwrapper.project.postmakevirtualenvproject")
        (test-path "$env:WORKON_HOME/xxx.out")
    }

    makeTestCase
}

$TestCase_Templates = {
    $setUpTestCase = {
        param($Logic)

        $oldLocation = get-location

        $fakeWorkonHome = _MakeFakeWorkonHome "PowerTestTests"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -Name "FOO"
        _MakeFakeVirtualEnvironment -WorkonHome $fakeWorkonHome -Name "BAR"
        $newProjectsHome = "$fakeWorkonHome/PROJECTS"
        [void] (new-item -itemtype "d" -path $newProjectsHome -force)
        [void] (new-item -itemtype "d" -path "$newProjectsHome/BAR" -force)

        [void] (new-item -itemtype "f" -path "$fakeWorkonHome/FOO/.project" -force)
        "$newProjectsHome/BAR" | out-file -filepath "$fakeWorkonHome/FOO/.project" -encoding "utf8"

        # redefine these two function so they are accessible in this scope without
        # loading virtualenvwrapper-powershell.
        function New-VirtualEnvironment { $true }

        $ProjectHome = $newProjectsHome
        $env:WORKON_HOME = $fakeWorkonHome
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/FOO"

        & $Logic

        set-location $oldLocation
        remove-item -path $fakeWorkonHome -recurse
    }

    $test_NonExistantTemplatesSource = {
        try {
            mkproject -envname "xxx" -templates "foo"
            $false
        }
        catch {
            $_.exception.message -eq "Set the `$VirtualenvWrapperTemplates variable to point to an existing directory containing the templates."
        }
    }

    $test_NonExistantTemplate = {
        $VirtualenvWrapperTemplates = $env:WORKON_HOME
        [void] (mkproject -envname "xxx" -templates "foo") 2> $null

         # this is a non-terminating error, so we can't try/catch it.
         $error[0].exception.message -eq "Template 'foo' not found. Not applying."
    }

    $test_Template = {
        $VirtualenvWrapperTemplates = $env:WORKON_HOME
        [void] (set-content -path "$VirtualenvWrapperTemplates/Project.Template.Foo.ps1" `
                    -value "[void] (new-item -itemtype 'f' -path '$env:WORKON_HOME/foo.xxx')" `
                    -encoding "utf8")
        [void] (mkproject -envname "xxx" -templates "foo")

        (test-path "$env:WORKON_HOME/foo.xxx")
    }

    makeTestCase
}

makeTestSuite
