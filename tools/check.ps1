$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Set-Location $taskRoot
$env:APPDATA = Join-Path $taskRoot '.tools/test-userdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$engine = Join-Path $taskRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$importLog = & $engine --headless --path $taskRoot --editor --import --quit 2>&1
$importExit = $LASTEXITCODE
$importLog | Write-Output
if ($importExit -ne 0 -or (($importLog -join "`n") -match 'SCRIPT ERROR|ERROR:')) { throw 'Import failed' }
$testLog = & $engine --headless --path $taskRoot --script tests/run_tests.gd --quit-after 600 2>&1
$testExit = $LASTEXITCODE
$testLog | Write-Output
if ($testExit -ne 0 -or (($testLog -join "`n") -match 'SCRIPT ERROR|ERROR:') -or (($testLog -join "`n") -notmatch 'CHECKS: [0-9]+ \| FAILURES: 0')) { throw 'Tests failed or did not finish' }

$env:APPDATA = Join-Path $taskRoot '.tools/integration-userdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$campaignLog = & $engine --headless --path $taskRoot --script tests/campaign_tests.gd --quit-after 600 2>&1
$campaignExit = $LASTEXITCODE
$campaignLog | Write-Output
if ($campaignExit -ne 0 -or (($campaignLog -join "`n") -match 'SCRIPT ERROR|ERROR:') -or (($campaignLog -join "`n") -notmatch 'CAMPAIGN CHECKS: [0-9]+ \| FAILURES: 0')) { throw 'Campaign tests failed or did not finish' }

$env:APPDATA = Join-Path $taskRoot '.tools/close-userdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$closeLog = & $engine --headless --path $taskRoot --script tests/close_check.gd --quit-after 600 2>&1
$closeExit = $LASTEXITCODE
$closeLog | Write-Output
if ($closeExit -ne 0 -or (($closeLog -join "`n") -match 'SCRIPT ERROR|ERROR:') -or (($closeLog -join "`n") -notmatch 'CLOSE CHECK: latest preparation saved')) { throw 'Window close test failed' }
