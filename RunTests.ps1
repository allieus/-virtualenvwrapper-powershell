param($Filter="Test*", $FilterTestCase="*", $FilterTestName="*")

push-location "Tests"
    . "./powertests/powertests.ps1"
    Run-Test -filter $filter -FilterTestCase $FilterTestCase -FilterTestName $FilterTestName
pop-location
