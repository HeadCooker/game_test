$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Set-Location $taskRoot
$env:APPDATA = Join-Path $taskRoot '.tools/export-userdata'
New-Item -ItemType Directory -Force $env:APPDATA, 'build' | Out-Null
$engine = Join-Path $taskRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $engine --headless --path $taskRoot --export-release 'Windows Desktop' 'build/AlienEvacuation.exe'
if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
Copy-Item 'LICENSES' 'build' -Recurse -Force
Copy-Item 'docs/试玩说明.txt' 'build/试玩说明.txt' -Force
Compress-Archive -Path 'build/AlienEvacuation.exe', 'build/AlienEvacuation.pck', 'build/LICENSES', 'build/试玩说明.txt' -DestinationPath 'build/AlienEvacuation-Windows-x64.zip' -Force
