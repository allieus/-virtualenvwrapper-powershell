$SetUp = {
    # Remove and store current modules to be able to restore them later.
    $script:_modules = get-module
    $script:_modules | remove-module -erroraction silentlycontinue

    $script:_oldWorkonHome = $env:WORKON_HOME

    $global:__TEMP_WORKON_HOME = CreateTempDir
    $global:__OLD_WORKON_HOME = $env:WORKON_HOME
    $env:WORKON_HOME = $global:__TEMP_WORKON_HOME

    $script:pathToModule = "../virtualenvwrapper/Extensions/Extension.UserScripts.ps1"
    # & $script:pathToModule

    $script:GLOBAL_HOOKS = (
        'VEW_PreMakeVirtualEnv.ps1',
        'VEW_PostMakeVirtualEnv.ps1',
        'VEW_PreRemoveVirtualEnv.ps1',
        'VEW_PostRemoveVirtualEnv.ps1',
        'VEW_PreActivateVirtualEnv.ps1',
        'VEW_PostActivateVirtualEnv.ps1',
        'VEW_PreDeactivateVirtualEnv.ps1',
        'VEW_PostDeactivateVirtualEnv.ps1'
        )

    $script:LOCAL_HOOKS = (
        'VEW_PreActivateVirtualEnv.ps1',
        'VEW_PostActivateVirtualEnv.ps1',
        'VEW_PreDeactivateVirtualEnv.ps1',
        'VEW_PostDeactivateVirtualEnv.ps1'
        )
}


${TestCase_ - Event Subscribers Registration} = {
    
    ${test_ - Number of Subscribers} = {
        & $script:pathToModule

        (get-eventsubscriber 'VirtualenvWrapper.*').length -eq `
                                    # hooks plus two more to generate the hook scripts
                                    ($GLOBAL_HOOKS.count + $LOCAL_HOOKS.count) + 2

        unregister-event -sourceidentifier 'VirtualenvWrapper.*'
        remove-job -name 'VirtualenvWrapper.*'
    }

    makeTestCase
}


${TestCase_ - Respond Initialize Event} = {

    ${test_ - Create hook scripts } = {
        & $script:pathToModule

        [void] (new-event -sourceidentifier 'VirtualenvWrapper.Initialize')

        $new_hooks = (get-childitem $env:WORKON_HOME -filter "VEW_*" | `
                                            select-object -expandproperty name)
        $new_hooks.count -eq $script:GLOBAL_HOOKS.count

        foreach ($h in $new_hooks)
        {
            if (-not ($GLOBAL_HOOKS -eq $h))
            {
                $false
                break
            }
        }

        unregister-event -sourcei 'VirtualenvWrapper.*' -force
        remove-job -name 'VirtualenvWrapper.*'
    }

    ${test_ - Create local hook scripts} = {
        & $script:pathToModule

        [void] (new-item -itemtype 'directory' "$env:WORKON_HOME/xxx/Scripts")
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PreMakeVirtualEnv' -eventarguments 'xxx')
        $new_hooks = (get-childitem "$env:WORKON_HOME/xxx/Scripts" -filter "VEW_*" | `
                                            select-object -expandproperty name)
        $new_hooks.count -eq $script:LOCAL_HOOKS.count

        foreach ($h in $new_hooks)
        {
            if (-not ($GLOBAL_HOOKS -eq $h))
            {
                $false
                break
            }
        }

        unregister-event -sourcei 'VirtualenvWrapper.*' -force
        remove-job -name 'VirtualenvWrapper.*'
    }

    makeTestCase
}


${TestCase_ - Respond to events from global hooks} = {

    ${test_ - Trigger Global Scripts } = {
        & $script:pathToModule

        remove-item "$env:WORKON_HOME/xxx/Scripts/*" -force

        get-childitem "$env:WORKON_HOME/VEW_*" | foreach-object {
                            add-content $_ -value "Add-Content `"$env:WORKON_HOME/RESULTS.txt`" $($_.name)"
                        }
                
        # XXX XXX XXX XXX
        # The PreMakeVirtualEnv is triggered already although there's no event listener?
        # If the engine event registration is removed from the test above, RESULTS.txt isn't created.
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PreMakeVirtualEnv' -eventarguments 'xxx') 
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PostMakeVirtualEnv') 
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PreRemoveVirtualEnv') 
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PostRemoveVirtualEnv') 
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PreActivateVirtualEnv') 
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PostActivateVirtualEnv') 
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PreDeactivateVirtualEnv') 
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PostDeactivateVirtualEnv') 

        # If we don't stop for a while, the results file will be cleaned up before
        # the subprocesses have had a chance to write it??
        start-sleep -milli 10000 

        # XXX Se above. This will fail because PREMAKEVIRTUALENV hook will be
        # fired off twice.
        $lines = @(get-content -path "$env:WORKON_HOME/RESULTS.txt")

        $lines.count -eq $GLOBAL_HOOKS.count
        
        foreach ($h in $lines)
        {
            if (-not ($GLOBAL_HOOKS -eq $h))
            {
                $false
                break
            }
        }

        unregister-event -sourceidentifier 'VirtualenvWrapper.*' -force
        remove-job -name 'VirtualenvWrapper.*'
    }

    makeTestCase
}

${TestCase_ Ensure some hooks can affect global scope} = {
    ${test_ - Local Hooks } = {
        & $script:pathToModule

        get-childitem "$env:WORKON_HOME/xxx/Scripts/VEW_*" | foreach-object {
                            add-content $_ -value "`$global:XXX = '$($_.name)'"
                        }
                
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PreActivateVirtualEnv' -eventarguments 'xxx') 
        $global:XXX -eq 'VEW_PreActivateVirtualEnv.ps1'
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/xxx"
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PostActivateVirtualEnv' -eventarguments 'xxx') 
        $global:XXX -eq 'VEW_PostActivateVirtualEnv.ps1'
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PostDeactivateVirtualEnv' -eventarguments 'xxx') 
        $global:XXX -eq 'VEW_PostDeactivateVirtualEnv.ps1'
        # # XXX We're assuming that $env:VIRTUAL_ENV is set properly where it has to be.
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/xxx"
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PreDeactivateVirtualEnv') 
        $global:XXX -eq 'VEW_PreDeactivateVirtualEnv.ps1'
        # [void] (new-event -sourceidentifier 'VirtualenvWrapper.PostDeactivateVirtualEnv' -eventarguments 'xxx') 

        unregister-event -sourceidentifier 'VirtualenvWrapper.*' -force
        remove-job -name 'VirtualenvWrapper.*'
    }

    makeTestCase
}

${TestCase_ - Respond to events from local hooks} = {

    ${test_ - Trigger Global Scripts } = {
        & $script:pathToModule

        get-childitem "$env:WORKON_HOME/xxx/Scripts/VEW_*" | foreach-object {
                            add-content $_ -value "Add-Content `"$env:WORKON_HOME/xxx/RESULTS.txt`" $($_.name)"
                        }
                
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PreActivateVirtualEnv' -eventarguments 'xxx') 
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PostDeactivateVirtualEnv' -eventarguments 'xxx') 
        # XXX We're assuming that $env:VIRTUAL_ENV is set properly where it has to be.
        $env:VIRTUAL_ENV = "$env:WORKON_HOME/xxx"
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PreDeactivateVirtualEnv') 
        [void] (new-event -sourceidentifier 'VirtualenvWrapper.PostDeactivateVirtualEnv' -eventarguments 'xxx') 

        $lines = @(get-content -path "$env:WORKON_HOME/xxx/RESULTS.txt")

        $lines.count -eq $LOCAL_HOOKS.count

        foreach ($h in $lines)
        {
            if (-not ($LOCAL_HOOKS -eq $h))
            {
                $false
                break
            }
        }
        
        unregister-event -sourceidentifier 'VirtualenvWrapper.*' -force
        remove-job -name 'VirtualenvWrapper.*'
    }

    makeTestCase
}


$TearDown = {
    unregister-event 'VirtualEnvWrapper.*'
    remove-job "VirtualenvWrapper.*" -force
    # Restore modules.
    get-module | remove-module -erroraction silentlycontinue
    remove-item $env:WORKON_HOME -recurse -force
    $env:WORKON_HOME = $script:_oldWorkonHome
    $script:_modules | foreach-object { import-module $_.name }
}

makeTestSuite
