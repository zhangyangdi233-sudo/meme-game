@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "ROOT=%SCRIPT_DIR%.."

if "%~1"=="-h" goto :usage
if "%~1"=="--help" goto :usage
if "%~1"=="/?" goto :usage

if "%GODOT_BIN%"=="" (
    if exist "C:\Godot\Godot_v4.6.3-stable_win64.exe" (
        set "GODOT_BIN=C:\Godot\Godot_v4.6.3-stable_win64.exe"
    ) else (
        echo [run_tests] GODOT_BIN is not set.
        echo.
        echo Set your Godot 4.6+ executable, for example:
        echo   set GODOT_BIN=C:\Godot\Godot_v4.6.3-stable_win64.exe
        echo.
        echo Then run:
        echo   tools\run_tests.bat
        echo   tools\run_tests.bat -Fast
        exit /b 2
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run_tests.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
exit /b %EXIT_CODE%

:usage
echo Usage: tools\run_tests.bat [-Fast] [-Filter REGEX] [-SkipPython] [-GodotBin PATH]
echo.
echo   -Fast         Skip tests that load scenes/babel_meme_game.tscn
echo   -Filter       Only run tests whose file name matches REGEX
echo   -SkipPython   Skip tests/test_hand_tracker_*.py
echo   -GodotBin     Override GODOT_BIN for this run
echo.
echo Environment:
echo   GODOT_BIN     Path to Godot 4.6+ executable
echo.
echo Examples:
echo   set GODOT_BIN=C:\Godot\Godot_v4.6.3-stable_win64.exe
echo   tools\run_tests.bat -Fast
echo   tools\run_tests.bat -Filter rule_engine
exit /b 0
