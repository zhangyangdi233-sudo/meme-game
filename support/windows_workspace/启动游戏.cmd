@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Aphasia.ps1"
if errorlevel 1 pause

