param([switch]$Editor)

$ErrorActionPreference = 'Stop'
$projectPath = Join-Path $PSScriptRoot 'meme-game'
$enginePath = Join-Path $PSScriptRoot 'tools\godot-4.6.3\Godot_v4.6.3-stable_win64.exe'
$trackerPython = Join-Path $PSScriptRoot 'tools\hand-tracking-venv\Scripts\python.exe'
$logDirectory = Join-Path $PSScriptRoot 'outputs\local_runtime'

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Godot 4.6.3 was not found: $enginePath"
}
if (-not (Test-Path -LiteralPath (Join-Path $projectPath 'project.godot') -PathType Leaf)) {
    throw "The game project was not found: $projectPath"
}
if (Test-Path -LiteralPath $trackerPython -PathType Leaf) {
    $env:BABEL_HAND_TRACKER_PYTHON = $trackerPython
}
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$mode = if ($Editor) { 'editor' } else { 'game' }
$logPath = Join-Path $logDirectory ($mode + '_latest.log')
$engineArguments = @('--path', ('"{0}"' -f $projectPath), '--log-file', ('"{0}"' -f $logPath))
if ($Editor) {
    $engineArguments += '--editor'
}
$process = Start-Process -FilePath $enginePath -WorkingDirectory $projectPath -ArgumentList $engineArguments -PassThru
Write-Output ("Started {0}: PID {1}" -f $mode, $process.Id)

