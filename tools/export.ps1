$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Set-Location $taskRoot
$env:APPDATA = Join-Path $taskRoot '.tools/export-userdata'
New-Item -ItemType Directory -Force $env:APPDATA, 'build' | Out-Null
$engine = Join-Path $taskRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $engine --headless --path $taskRoot --export-release 'Windows Desktop' 'build/AlienEvacuation.exe'
if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
$packPath = Join-Path $taskRoot 'build/AlienEvacuation.pck'
$packScript = Join-Path $taskRoot 'tests/export_check.gd'
$packLog = & $engine --headless --path (Join-Path $taskRoot 'build') --main-pack $packPath --script $packScript --quit-after 600 2>&1
$packExit = $LASTEXITCODE
$packLog | Write-Output
if ($packExit -ne 0 -or (($packLog -join "`n") -match 'SCRIPT ERROR|ERROR:') -or (($packLog -join "`n") -notmatch 'EXPORTED CHECK: six missions')) { throw 'Exported content validation failed' }
Copy-Item 'LICENSES' 'build' -Recurse -Force
Copy-Item 'docs/试玩说明.txt' 'build/试玩说明.txt' -Force
Compress-Archive -Path 'build/AlienEvacuation.exe', 'build/AlienEvacuation.pck', 'build/LICENSES', 'build/试玩说明.txt' -DestinationPath 'build/AlienEvacuation-Windows-x64.zip' -Force
New-Item -ItemType Directory -Force 'release' | Out-Null
Copy-Item 'build/AlienEvacuation-Windows-x64.zip' 'release/AlienEvacuation-Windows-x64.zip' -Force
