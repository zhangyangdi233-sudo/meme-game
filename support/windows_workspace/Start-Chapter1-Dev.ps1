$ErrorActionPreference = 'Stop'
$projectPath = Join-Path $PSScriptRoot 'meme-game'
$enginePath = Join-Path $PSScriptRoot 'tools\godot-4.6.3\Godot_v4.6.3-stable_win64.exe'
$logDirectory = Join-Path $PSScriptRoot 'outputs\chapter1_development'
$trackerPython = Join-Path $PSScriptRoot 'tools\hand-tracking-venv\Scripts\python.exe'

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Godot 4.6.3 was not found: $enginePath"
}
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
# Developer saves and preferences are separate from the ordinary launcher.
$env:APPDATA = Join-Path $logDirectory 'profile'
if (Test-Path -LiteralPath $trackerPython -PathType Leaf) {
    $env:BABEL_HAND_TRACKER_PYTHON = $trackerPython
}
$logPath = Join-Path $logDirectory 'chapter1_latest.log'
$engineArguments = @('--path', ('"{0}"' -f $projectPath), '--log-file', ('"{0}"' -f $logPath), '--', '--chapter1-dev')
# This is the interactive game the user launches intentionally.
$process = Start-Process -FilePath $enginePath -WorkingDirectory $projectPath -ArgumentList $engineArguments -PassThru
Write-Output ("Chapter 1 development mode: PID {0}. Choose New Game; DEV controls simulate unfinished narration and NPC tasks." -f $process.Id)
