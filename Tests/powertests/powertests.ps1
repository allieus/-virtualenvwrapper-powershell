#requires -version 2.0
# set-strictmode -version '2.0'

. "$(split-path $MyInvocation.MyCommand.Path -parent)/misc.ps1"

set-variable TEST_STATUS_ERROR  -value -1 -option "CONSTANT"
set-variable TEST_STATUS_FAILED -value 0 -option "CONSTANT"
set-variable TEST_STATUS_PASSED -value 1 -option "CONSTANT"
set-variable STOPWATCH -value (new-object "system.diagnostics.stopwatch") -option "CONSTANT"


# Create a new test result object.
function New_TestResult {
    param([int]$Status,
          [string]$Source,
          # TODO: we should accept an error field too for tests throwing errors.
          # $TestCase should then become a [system.management.automation.psvariable]
          [object]$TestCase,
          [timespan]$TimeElapsed)

    function AddNoteProperty {
        param($Target, $Name, $Value)
        $target | add-member -membertype "NoteProperty" `
                             -name       $Name `
                             -value      $Value
    }

    $o = new-object "PSObject"
    AddNoteProperty $o "Status" $Status
    AddNoteProperty $o "Source" $Source
    AddNoteProperty $o "TestCase" $TestCase
    AddNoteProperty $o "TimeElapsed" $TimeElapsed
    $o
}


# Functions for test definition
#==============================================================================
function getTestVariables {
    param([string]$NamePattern, $Scope)
    # Gets test cases in the parent scope.
    $testCases = (get-variable -scope $Scope) | where-object {
                                                        $_.value -is [scriptblock] -and
                                                        $_.name -like $NamePattern
                                                        }
    $testCases | sort-object -property @{Expression={ $_.value.startposition.start }}
}


function makeTestSuite {
    $testEnvironment = getTestVariables "setUpTestSuite" -scope 2
    $testCases = getTestVariables "TestCase*" -scope 2
    $testEnvironment, @($testCases)
}


function makeTestCase {
    $testCaseEnvironment = getTestVariables "setUpTestCase" -scope 2
    $testCaseTests = getTestVariables "test*" -scope 2
    $testCaseEnvironment, $testCaseTests
}


function doesTestPass {
    param([management.automation.psvariable]$Test)
    $values = & $Test.value
    ([bool]@($values).length) -and ((@($values) -eq $false).length -eq 0)
}
#==============================================================================


# Functions for test result formatting
#==============================================================================
function FormatFailedTests {
    param($failedTests)

    foreach ($fail in $failedTests) {
        write-host -foreground "DarkYellow" ("FAILED: {0}{1}[{2}:{3}]" -f
                                                $fail.source,
                                                $fail.testcase.Name,
                                                $fail.testcase.value.startposition.startline,
                                                $fail.testcase.value.startposition.startcolumn)
        write-host $fail.testcase.value
    }
}

function FormatTestsWithErrors {
    # in powershell, there seems to be two types of error info objects:
    # - exceptions (they have an ErrorRecord property)
    # - ErrorRecord
    # We'll try to always use the ErrorRecord member to extract info.
    param($errorTests)

    foreach($err in $errorTests) {

        $errRecord = $err.testcase
        if ($err.testcase -isnot [system.management.automation.errorrecord]) {
            $errRecord = $err.testcase.ErrorRecord
        }

        write-host -foreground "DarkRed" ("ERROR: {0}[{1}:{2}]" -f
                                                $errRecord.invocationinfo.scriptname,
                                                $errRecord.invocationinfo.scriptlinenumber,
                                                $errRecord.invocationinfo.offsetinline)
        write-host $err.testcase
        write-host $errRecord.invocationinfo.line
    }
}

function Format-TestResult {
    param([System.Object[]]$TestResults,
          [switch]$NoNewLineAtEndOfTest=$True,
          [switch]$NoNewLineAtEnd
    )

    $failedTests = @()
    $errorTests = @()
    [timespan]$totalTime = 0

    write-host ("`n" + "-"*78) -ForegroundColor "DarkGray" -NoNewline

    # In PS, $null | %{ "foo" } will print "foo". Make sure we don't try
    # to operate on $null.
    if ($testResults -eq $null) {
        $testResults = @()
    }

    foreach ($result in $TestResults) {
        $totalTime += $result.timeelapsed
        switch ($result.status) {
             $TEST_STATUS_ERROR  { $errorTests  += ,$result; break }
             $TEST_STATUS_FAILED { $failedTests += ,$result; break }
             $TEST_STATUS_PASSED { break }
             default {
                write-debug "Formatting (default): $($result.status)"
                write-host -foreground red "You shouldn't be seeing this." }
        }

        if (-not $NoNewLineAtEndOfTest) {
            write-host
        }
    }

    if (-not $NoNewLineAtEnd) {
        write-host
    }

    if ($failedTests -or $errorTests) {
        write-debug "Failed Tests: $failedTests"
        write-debug "Error Tests: $errorTests"

        FormatFailedTests $failedTests
        FormatTestsWithErrors $errorTests
    }

    write-host ("-"*78) -ForegroundColor "DarkGray"
    write-host "Tests: $($TestResults.length) | " -NoNewline
    write-host "Failed: $($failedTests.length) | " -NoNewline
    write-host "Errors: $($errorTests.length) | " -NoNewline
    write-host "Time: $($totalTime)" -ForegroundColor "Gray"
    write-host ("="*78) -ForegroundColor "DarkGray"

}


# Functions for test running
#==============================================================================
function Invoke-TestSuite {
    param($SourceFileName,
          $TestSuite,
          $Environ=$null
    )

    $source = "[$SourceFileName]::$($TestSuite.Name)::"
    try {
        $testCaseEnvironment, $tests = & $TestSuite.value
        $testCaseEnvironment = $testCaseEnvironment.Value
    }
    catch {
        if ($_.FullyQualifiedErrorId -eq "BadExpression") {
            write-error -message "Can't run test suite. Make sure you are using 'makeTestCase' and 'makeTestSuite' as appropriate."
            return
        }
        throw $_
    }

    if (-not $testCaseEnvironment) {
        $testCaseEnvironment = {
            param($Logic)
            & $Logic
        }
    }

    foreach ($t in @($tests)) {
        $theLogic = {
            $STOPWATCH.start()
            try {
                if (doesTestPass $t) {
                    Write-Debug "Test Passed: $source - $($t.Name)"
                    $STOPWATCH.stop()
                    New_TestResult $TEST_STATUS_PASSED $source $t $STOPWATCH.elapsed
                    [void] (New-Event -SourceIdentifier "PowerTest.Success")
                }
                else {
                    $STOPWATCH.stop()
                    Write-Debug "Test Failed: $source - $($t.Name)"
                    New_TestResult $TEST_STATUS_FAILED $source $t $STOPWATCH.elapsed
                    [void] (New-Event -SourceIdentifier "PowerTest.Fail")
                }
            }
            catch {
                $STOPWATCH.stop()
                Write-Debug "Test Error: $source - $($t.Name) - $_"
                New_TestResult $TEST_STATUS_ERROR $source $_ $STOPWATCH.elapsed
                [void] (New-Event -SourceIdentifier "PowerTest.Error")
            }

        }
        & $testCaseEnvironment $theLogic
        $STOPWATCH.reset()
    }
}


function Invoke-PowerTest {
    param([System.Collections.HashTable]$TestCollection)
    process {
        foreach ($keyValuePair in $TestCollection.GetEnumerator()) {

            if (!$keyValuePair.value) {
                continue
            }

            write-debug "Invoking test cases in: $($keyValuePair.Key) ($($keyValuePair.Value.Length))"
            foreach ($testSuite in $keyValuePair.Value[1])
            {
                $testSuiteEnvironment = $keyValuePair.Value[0].Value
                if (-not $testSuiteEnvironment) {
                    $testSuiteEnvironment = {
                        param($Logic)
                        & $Logic
                    }
                }

                $logic = { Invoke-TestSuite -SourceFileName $keyValuePair.key `
                                            -TestSuite $testSuite `
                                            -Environ $keyValuePair.Value[0].Value }
                & $testSuiteEnvironment $logic
            }
        }
    }
}
#==============================================================================


# Functions for test collection
#==============================================================================
function Get-PowerTest {
    # TODO: find tests recursively too.
    param($Path, $Filter="Test*.ps1")
    write-debug "Collecting tests from: $Path"

    $testCollection = @{}
    foreach ($file in (Get-ChildItem -Path $Path -Filter $Filter))
    {
        write-debug "Collected test matching: $file"
        $testCollection[$file.name] += @(& $file.fullname)
    }

    $testCollection
}
#==============================================================================


# Main program for test discovery
#==============================================================================
function Run-Test {
    param($Path=(Get-Location), $Filter="Test*.ps1")

    try {

        # unload all modules (todo: too drastic?)
        $__moduleNames = get-module | select-object -expandproperty "name"
        remove-module (get-module)

        if (!((test-path $path) -and (get-item $path).PSIsContainer)) {
            write-error -message "Cannot find specified path or it isn't a directory."
            return
        }

        # These events allow to write live feedback about test results.
        [void] (Register-EngineEvent -SourceIdentifier "PowerTest.Success" -Action { Write-Host "." -ForegroundColor "DarkGreen" -NoNewline })
        [void] (Register-EngineEvent -SourceIdentifier "PowerTest.Fail"    -Action { Write-Host "F" -ForegroundColor "DarkRed" -NoNewline })
        [void] (Register-EngineEvent -SourceIdentifier "PowerTest.Error"   -Action { Write-Host "E" -ForegroundColor "Red" -NoNewline })

        $testCollection = Get-PowerTest -Path $Path -Filter $Filter
        if ($testCollection.Count -eq 0) {
            write-error -message "Could not find any files in '$Path' matching '$Filter'."
            return
        }

        $testResults = Invoke-PowerTest -TestCollection $testCollection
        Format-TestResult -TestResult $testResults

        Unregister-Event -SourceIdentifier "PowerTest.*"
    }
    finally {
        $__moduleNames | import-module
    }
}
