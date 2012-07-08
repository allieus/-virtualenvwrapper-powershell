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
        $host.ui.writeline(("FAILED: {0}{1}[{2}:{3}]" -f
                                                $fail.source,
                                                $fail.testcase.Name,
                                                $fail.testcase.value.startposition.startline,
                                                $fail.testcase.value.startposition.startcolumn))
        $host.ui.writeline($fail.testcase.value)
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

        $host.ui.writeerrorline(("ERROR: {0}[{1}:{2}]" -f
                                                $errRecord.invocationinfo.scriptname,
                                                $errRecord.invocationinfo.scriptlinenumber,
                                                $errRecord.invocationinfo.offsetinline))
        $host.ui.writeline($err.testcase)
        $host.ui.writeline($errRecord.invocationinfo.line)
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

    $host.ui.write(("`n" + "-"*78))

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
                $host.ui.writeerrorline("You shouldn't be seeing this.") }
        }

        if (-not $NoNewLineAtEndOfTest) {
            $host.ui.writeline()
        }
    }

    if (-not $NoNewLineAtEnd) {
        $host.ui.writeline()
    }

    if ($failedTests -or $errorTests) {
        write-debug "Failed Tests: $failedTests"
        write-debug "Error Tests: $errorTests"

        FormatFailedTests $failedTests
        FormatTestsWithErrors $errorTests
    }

    $host.ui.writeline("-"*78)
    $host.ui.write("Tests: $($TestResults.length) | ")
    $host.ui.write("Failed: $($failedTests.length) | ")
    $host.ui.write("Errors: $($errorTests.length) | ")
    $host.ui.writeline("Time: $($totalTime)")
    $host.ui.writeline("="*78)

}


# Functions for test running
#==============================================================================
function Invoke-TestSuite {
    param($SourceFileName,
          $TestSuite,
          $Environ=$null,
          $FilterTestName="*"
    )

    $source = "[$SourceFileName]::$($TestSuite.Name)::"
    try {
        $testCaseEnvironment, $tests = & $TestSuite.value
        $testCaseEnvironment = $testCaseEnvironment.Value
    }
    catch {
        if ($_.FullyQualifiedErrorId -eq "BadExpression") {
            $host.ui.writeerrorline("Can't run test suite. Make sure you are using 'makeTestCase' and 'makeTestSuite' as appropriate.")
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
        if ($t.name -notlike $FilterTestName) {
            continue
        }
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
    param([System.Collections.HashTable]$TestCollection,
          [string]$FilterTestCase="*",
          [string]$FilterTestName="*")
    process {
        foreach ($keyValuePair in $TestCollection.GetEnumerator()) {

            if (!$keyValuePair.value) {
                continue
            }

            write-debug "Invoking test cases in: $($keyValuePair.Key) ($($keyValuePair.Value.Length))"
            foreach ($testSuite in $keyValuePair.Value[1])
            {
                if ($testSuite.name -notlike $FilterTestCase) {
                    continue
                }
                $testSuiteEnvironment = $keyValuePair.Value[0].Value
                if (-not $testSuiteEnvironment) {
                    $testSuiteEnvironment = {
                        param($Logic)
                        & $Logic
                    }
                }

                $logic = { Invoke-TestSuite -SourceFileName $keyValuePair.key `
                                            -TestSuite $testSuite `
                                            -Environ $keyValuePair.Value[0].Value `
                                            -FilterTestName $FilterTestName }
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
    param($Path=(Get-Location), $Filter="Test*.ps1", $FilterTestCase="*",
          $FilterTestName="*")

    try {

        # unload all modules (todo: too drastic?)
        $__moduleNames = @(get-module | select-object -expandproperty "name")
        get-module | remove-module

        $global:_capturedOutput = @()
        function write-host { $global:_capturedOutput += $args }
        # TODO: capturing stderr is problematic when tests need to check for
        # errors.
        # function write-error { $global:_capturedOutput += $args }

        if (!((test-path $path) -and (get-item $path).PSIsContainer)) {
            $host.ui.writeerrorline("Cannot find specified path or it isn't a directory.")
            return
        }

        # These events allow to write live feedback about test results.
        [void] (Register-EngineEvent -SourceIdentifier "PowerTest.Success" -Action { $host.ui.write(".") })
        [void] (Register-EngineEvent -SourceIdentifier "PowerTest.Fail"    -Action { $host.ui.write("F") })
        [void] (Register-EngineEvent -SourceIdentifier "PowerTest.Error"   -Action { $host.ui.write("E") })

        $testCollection = Get-PowerTest -Path $Path -Filter $Filter
        if ($testCollection.Count -eq 0) {
            $host.ui.writeerrorline("Could not find any files in '$Path' matching '$Filter'.")
            return
        }

        $testResults = Invoke-PowerTest -TestCollection $testCollection `
                                        -FilterTestCase $FilterTestCase `
                                        -FilterTestName $FilterTestName
        Format-TestResult -TestResult $testResults

        if ($_capturedOutput) {
            $_capturedOutput
        }

    }
    finally {
        Unregister-Event -SourceIdentifier "PowerTest.*"
        $__moduleNames | import-module
        remove-item function:write-host
        remove-item variable:_capturedOutput
    }
}
