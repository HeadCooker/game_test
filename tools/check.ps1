$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Set-Location $taskRoot
$env:APPDATA = Join-Path $taskRoot '.tools/test-userdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$engine = Join-Path $taskRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $engine --headless --path $taskRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $engine --headless --path $taskRoot --script tests/run_tests.gd
if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
