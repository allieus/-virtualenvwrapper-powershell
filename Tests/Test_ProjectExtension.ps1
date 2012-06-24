# $script:thisDir = split-path $MyInvocation.MyCommand.Path -parent
# assume we're executing from the Tests directory.

$setUpTestSuite = {
    param($logic)

    $_oldVirtualEnv = $env:VIRTUAL_ENV
    $_oldWORKON_HOME = $env:WORKON_HOME
    if (test-path variable:ProjectHome) { $_oldProjectHome = $global:ProjectHome }

    . "./../virtualenvwrapper/extensions/extension.project.ps1"

    & $logic

    remove-item alias:cdproject
    remove-item alias:mkproject
    unregister-event "virtualenvwrapper.*"

    $env:VIRTUAL_ENV = $_oldVirtualEnv
    $env:WORKON_HOME = $_oldWORKON_HOME
    if ($_oldProjectHome) {
        $global:ProjectHome = $_oldProjectHome
    }
    else {
        [void] (remove-item variable:ProjectHome -erroraction "SilentlyContinue")
    }
}

$TestCase_AreAliasAvailable = {
    $test_CdProjectAliasExists = {
        test-path alias:cdproject
        $alias = get-item alias:cdproject
        $alias.definition -eq "Set-LocationToProject"
    }

    $test_MkProjectAliasExists = {(test-path alias:mkproject)}

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
            # todo: isolate test environment; we havent's reset $ProjectHome.
            VEW_Project_VerifyProjectHome
        }
        catch {
            $_.Exception.Message -eq "You must set the `$ProjectHome variable to point to a directory."
        }
    }

    $test_ProjectHomePointsToInvalidDirectory = {
        try {
            # todo: is this safe as an invalid dir?
            $ProjectHome = "???:"
            # todo: isolate test environment; we havent's reset $ProjectHome.
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
        # make workon home
        $newWorkonHome = "$env:TEMP/PowerTestTests/WORKONHOME"
        $newProjectsHome = "$env:TEMP/PowerTestTests/PROJECTS"
        [void] (new-item -itemtype "d" -path $newWorkonHome -force)
        [void] (new-item -itemtype "d" -path $newProjectsHome -force)
        [void] (new-item -itemtype "d" -path "$newWorkonHome/FOO" -force)
        [void] (new-item -itemtype "d" -path "$newProjectsHome/BAR" -force)

        & $Logic

        remove-item -path "$env:TEMP/PowerTestTests" -recurse -force
    }

    $test_PassingANamedVirtualenv = {
        # todo supress write-host
        [void] (set-virtualenvproject -venv "$newWorkonHome/FOO" `
                                      -Project "$newProjectsHome/BAR")
        test-path "$newWorkonHome/FOO/.project"
        (get-content "$newWorkonHome/FOO/.project") -eq "$newProjectsHome/BAR"
    }

    $test_NoNamedVirtualenv = {
        $env:VIRTUAL_ENV = "$newWorkonHome/FOO"
        # todo supress write-host
        [void] (set-virtualenvproject -Project "$newProjectsHome/BAR")
        test-path "$newWorkonHome/FOO/.project"
        (get-content "$newWorkonHome/FOO/.project") -eq "$newProjectsHome/BAR"

    }

    $test_NoNamedProjectOrVirtualenv = {
        $env:VIRTUAL_ENV = "$newWorkonHome/FOO"
        # todo supress write-host
        [void] (set-virtualenvproject)
        test-path "$newWorkonHome/FOO/.project"
        (get-content "$newWorkonHome/FOO/.project") -eq (get-location).providerpath

    }

    $test_CantFindVirtualenv = {
        $env:VIRTUAL_ENV = "$newWorkonHome/XXX"
        # todo supress write-host
        try {
            [void] (set-virtualenvproject)
        }
        catch {
            $_.exception.message -eq "Can't find virtualenv."
        }

        -not (test-path "$newWorkonHome/XXX/.project")
    }

    $test_CantFindProjectDirectory = {
        $env:VIRTUAL_ENV = "$newWorkonHome/FOO"
        # todo supress write-host
        try {
            [void] (set-virtualenvproject -project "$newProjectsHome/XXX")
        }
        catch {
            $_.exception.message -eq "Can't find project directory."
        }

        -not (test-path "$newWorkonHome/FOO/.project")
    }

    makeTestCase
}

$TestCase_SetLocationToProeject = {
    $setUpTestCase = {
        param($Logic)
        # make workon home
        $newWorkonHome = "$env:TEMP/PowerTestTests/WORKONHOME"
        $newProjectsHome = "$env:TEMP/PowerTestTests/PROJECTS"
        [void] (new-item -itemtype "d" -path $newWorkonHome -force)
        [void] (new-item -itemtype "d" -path $newProjectsHome -force)
        [void] (new-item -itemtype "d" -path "$newWorkonHome/FOO" -force)
        [void] (new-item -itemtype "d" -path "$newProjectsHome/BAR" -force)

        [void] (new-item -itemtype "f" -path "$newWorkonHome/FOO/.project" -force)
        "$newProjectsHome/BAR" | out-file -filepath "$newWorkonHome/FOO/.project" -encoding "utf8"

        # redefine these two function so they are accessible in this scope without
        # loading virtualenvwrapper-powershell.
        function VerifyWorkonHome { $true }
        function VerifyVirtualEnv { $true }

        $env:VIRTUAL_ENV = "$newWorkonHome/FOO"
        $ProjectHome = "$newProjectsHome"

        & $Logic

        remove-item -path "$env:TEMP/PowerTestTests" -recurse -force
    }

    $test_ProjectFileDoesNotExist = {
        [void] (remove-item "$newWorkonHome/FOO/.project")
        try{
            Set-LocationToProject
        }
        catch {
            $_.exception.message -eq "No project set in $env:VIRTUAL_ENV/.project"
        }
    }

    $test_ProjectDirectoryDoesNotExist = {
        $projDir = "xzy:"
        [void] (set-content -path "$newWorkonHome/FOO/.project" -value $projDir -encoding "utf8")
        try{
            [void] (Set-LocationToProject)
            set-psdebug -Step
        }
        catch {
            $_.exception.message -eq "Project directory $projDir does not exist."
        }
    }

    $test_CanChangeCurrentDirectory = {
        $cwd = get-location
        try {
            [void] (Set-LocationToProject)
            (get-item "$newProjectsHome/BAR").path -eq (get-item (get-location)).path
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

        # make workon home
        $newWorkonHome = "$env:TEMP/PowerTestTests/WORKONHOME"
        $newProjectsHome = "$env:TEMP/PowerTestTests/PROJECTS"
        [void] (new-item -itemtype "d" -path $newWorkonHome -force)
        [void] (new-item -itemtype "d" -path $newProjectsHome -force)
        [void] (new-item -itemtype "d" -path "$newWorkonHome/FOO" -force)
        [void] (new-item -itemtype "d" -path "$newProjectsHome/BAR" -force)

        [void] (new-item -itemtype "f" -path "$newWorkonHome/FOO/.project" -force)
        "$newProjectsHome/BAR" | out-file -filepath "$newWorkonHome/FOO/.project" -encoding "utf8"

        # redefine these two function so they are accessible in this scope without
        # loading virtualenvwrapper-powershell.
        function New-VirtualEnvironment { $true }

        $env:VIRTUAL_ENV = "$newWorkonHome/FOO"
        $ProjectHome = "$newProjectsHome"

        & $Logic

        set-location $oldLocation
        remove-item -path "$env:TEMP/PowerTestTests" -recurse -force
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
        $env:VIRTUAL_ENV = "$newWorkonHome/NEWPROJECT"
        [void] (new-item -itemtype "d" "$newWorkonHome/NEWPROJECT")

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

        # make workon home
        $newWorkonHome = "$env:TEMP/PowerTestTests/WORKONHOME"
        $newProjectsHome = "$env:TEMP/PowerTestTests/PROJECTS"
        [void] (new-item -itemtype "d" -path $newWorkonHome -force)
        [void] (new-item -itemtype "d" -path $newProjectsHome -force)
        [void] (new-item -itemtype "d" -path "$newWorkonHome/FOO" -force)
        [void] (new-item -itemtype "d" -path "$newProjectsHome/BAR" -force)

        $env:WORKON_HOME = $newWorkonHome
        $env:VIRTUAL_ENV = "$newWorkonHome/FOO"
        $ProjectHome = "$newProjectsHome"

        & $Logic

        remove-item -path "$env:TEMP/PowerTestTests" -recurse -force
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

makeTestSuite
