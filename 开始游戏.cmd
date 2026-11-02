@echo off
cd /d "%~dp0"
if exist "build\AlienEvacuation.exe" (
    start "" "build\AlienEvacuation.exe"
) else (
    start "" ".tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
)
