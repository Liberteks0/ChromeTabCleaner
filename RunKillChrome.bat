@echo off
set SCRIPT="C:\Users\nvive\Desktop\KillChromeByPath.ps1"

:: Run the PowerShell script with execution policy bypass and hidden window
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File %SCRIPT%