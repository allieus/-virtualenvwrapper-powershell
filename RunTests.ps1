param($Filter="Test*")

push-location "Tests"
    . "./powertests/powertests.ps1"
    Run-Test -filter $filter
pop-location
