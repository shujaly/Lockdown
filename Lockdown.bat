@echo off
rem First run: builds Lockdown.exe, then starts it. After that you can open Lockdown.exe directly (no console window).
cd /d "%~dp0"
if not exist "Lockdown.exe" powershell -NoProfile -ExecutionPolicy Bypass -File "Build-Launcher.ps1"
if exist "Lockdown.exe" (start "" "Lockdown.exe") else (start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "Lockdown.ps1")
