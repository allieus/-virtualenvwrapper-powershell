# set-strictmode -version "2.0"


function Concat
{
    "$args"
}


# verify that the WORKON_HOME directory exists
function VerifyWorkonHome
{
    if (-not ((test-path env:WORKON_HOME) -and (test-path $env:WORKON_HOME)))
    {
        throw (new-object `
                    -typename "system.io.directorynotfoundexception" `
                    -argumentlist (Concat `
                                    "Virtualenvwrapper: Virtual environments directory" `
                                    "'$env:WORKON_HOME' does not exist. Create it or set" `
                                    "`$env:WORKON_HOME to an existing directory.")
                                    )
    }
}


# XXX: Test this.
# function RunHook
# {
#     $tmpfile = [io.path]::GetTempFileName() + ".ps1"
#     new-item -item f $tmpfile > $null
#     if (-not (test-path $tmpfile))
#     {
#         throw(new-object `
#                 -typename "System.IO.IOException" `
#                 -argumentlist (Concat `
#                                 "ERROR: Could not create temporary file name." `
#                                 "Unknown problem.")
#                                 )
#     }

#     & "$VIRTUALENVWRAPPER_PYTHON" "-c" 'from virtualenvwrapper.hook_loader import main; main()' --script "$tmpfile" $args

#     if ($LASTEXITCODE -eq 0)
#     {
#         if (-not (test-path $tmpfile))
#         {
#             throw(new-object `
#                     -typename "System.IO.FileNotFoundException" `
#                     -argumentlist "ERROR: RunHook could not find temporary file $tmpfile."
#                     )
#         }
#         . "$tmpfile"
#     }
#     remove-item $tmpfile
# }

# function RunHook { 
#    write-debug -Message "RUNNING HOOK..." 
# }

# XXX: Test this
# set up virtualenvwrapper properly
function Initialize
{
    try
    {
        VerifyWorkonHome
    }
    catch [System.IO.IOException]
    {
        throw($_)
    }

    get-childitem 'C:\Users\guillermo\Dev\powershell\virtualenvwrapper-win-compat-pure\virtualenvwrapper\Extensions' `
                    -Filter '*.ps1' | `
                                foreach-object { & $_.fullname }

    [void] (New-Event -SourceIdentifier 'VirtualEnvWrapper.Initialize')
    # RunHook "initialize"
}


function VerifyVirtualEnv
{
    $venv = get-command $global:VIRTUALENVWRAPPER_VIRTUALENV -erroraction silentlycontinue
    if (-not $venv)
    {
        throw(new-object `
                -typename "System.IO.FileNotFoundException" `
                -argumentlist "ERROR: virtualenvwrapper could not find virtualenv in your PATH."
                )
    }
    elseif (-not (test-path $venv.definition))
    {
        throw(new-object `
                -typename "System.IO.FileNotFoundException" `
                -argumentlist "ERROR: Found virtualenv in path as `"$venv`" but that does not exist."
                )        
    }
}


# verify that the requested environment exists
function VerifyWorkonEnvironment
{
    if (-not (test-path "$env:WORKON_HOME/$($args[0])"))
    {
        throw(new-object `
                        -typename "system.io.directorynotfoundexception" `
                        -argumentlist (Concat `
                                        "ERROR: Environment '$($args[0])' does" `
                                        "not exist. Create it with 'mkvirtualenv" `
                                        "$($args[0])'.")
                                        )
    }
}


# verify that the active environment exists
function VerifyActiveEnvironment
{
    if (-not ((test-path env:VIRTUAL_ENV) -and (test-path $env:VIRTUAL_ENV)))
    {
        throw(new-object `
                    -typename "system.io.ioexception" `
                    -argumentlist (Concat `
                                    "ERROR: no virtualenv active, or" `
                                    "active virtualenv is missing")
                                    )
    }
}

###############################################################################
# Formatting helpers
#------------------------------------------------------------------------------
filter LooksLikeAVirtualEnv
{
    param([IO.DirectoryInfo]$path)

    $_ | where-object { $_.PSIsContainer -and `
                        (test-path (join-path $_.FullName "Scripts/activate.ps1"))
                        }
}


function NewVirtualEnvData
{
    param([IO.DirectoryInfo]$path)

    $info = new-object 'PSObject' -property @{'PathInfo'=$path}
    add-member -inputobject $info `
                    -membertype 'ScriptProperty' `
                    -name 'Name' -value { $this.PathInfo.Name }
    add-member -inputobject $info `
                    -membertype 'NoteProperty' `
                    -name 'PathToScripts' -value (join-path $path.Fullname 'Scripts')
    add-member -inputobject $info `
                    -membertype 'NoteProperty' `
                    -name 'PathToSitePackages' -value (join-path $path.Fullname 'Lib/site-packages')
    # XXX: Find out whether PSCustomObject can be formatted with .ps1xml files.
    # http://blogs.msdn.com/b/powershell/archive/2006/04/30/how-powershell-formatting-and-outputting-really-works.aspx
    # add-member -inputobject $info -membertype 'ScriptProperty' -name 'Hooks' -value { get-childitem $this.PathToScripts -filter '*.ps1' }

    $info
}


function GetVirtualEnvData
{
    get-childitem $env:WORKON_HOME | LooksLikeAVirtualEnv | ForEach-Object { NewVirtualEnvData $_ }
}
###############################################################################