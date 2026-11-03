$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$archive = Join-Path $taskRoot 'release/AlienEvacuation-Windows-x64.zip'
$playerDir = Join-Path $taskRoot 'build/player'
$executable = Join-Path $playerDir 'AlienEvacuation.exe'
$stamp = Join-Path $playerDir 'package.sha256'
try {
    if (-not (Test-Path -LiteralPath $archive)) { throw 'Game package missing. Download or clone the complete repository.' }
    $packageHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    $installedHash = if (Test-Path -LiteralPath $stamp) { (Get-Content -LiteralPath $stamp -Raw).Trim() } else { '' }
    if ($installedHash -ne $packageHash -or -not (Test-Path -LiteralPath $executable) -or -not (Test-Path -LiteralPath (Join-Path $playerDir 'AlienEvacuation.pck'))) {
        Write-Host 'Preparing game files. Please wait...'
        New-Item -ItemType Directory -Force -Path $playerDir | Out-Null
        Expand-Archive -LiteralPath $archive -DestinationPath $playerDir -Force
        Set-Content -LiteralPath $stamp -Value $packageHash -Encoding ASCII
    }
    Start-Process -FilePath $executable -WorkingDirectory $playerDir
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
