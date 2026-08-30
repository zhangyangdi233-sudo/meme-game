param(
    [string]$GodotBin = $env:GODOT_BIN,
    [string]$Filter = "",
    [switch]$Fast,
    [switch]$SkipPython
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

function Show-Usage {
    Write-Host @"
Usage: tools/run_tests.ps1 [-GodotBin PATH] [-Fast] [-Filter REGEX] [-SkipPython]

  -GodotBin   Godot executable (default: `$env:GODOT_BIN)
  -Fast       Skip tests that instantiate scenes/babel_meme_game.tscn
  -Filter     Only run tests whose file name matches REGEX
  -SkipPython Skip tests/test_hand_tracker_*.py

Examples:
  `$env:GODOT_BIN = 'C:\Godot\Godot_v4.6.3-stable_win64.exe'
  .\tools\run_tests.ps1 -Fast
  .\tools\run_tests.ps1
"@
}

if ($args -contains "-h" -or $args -contains "--help") {
    Show-Usage
    exit 0
}

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    Write-Error "Godot not configured. Set -GodotBin or `$env:GODOT_BIN to your Godot 4.6+ executable."
}

if (-not (Test-Path -LiteralPath $GodotBin)) {
    Write-Error "Godot not found at: $GodotBin"
}

$testFiles = Get-ChildItem -Path (Join-Path $Root "tests") -Filter "test_*.gd" -File |
    Sort-Object Name

if ($testFiles.Count -eq 0) {
    Write-Error "No tests/test_*.gd files found."
}

$failures = New-Object System.Collections.Generic.List[string]
$passed = 0
$skipped = 0

foreach ($testFile in $testFiles) {
    if ($Filter -and ($testFile.BaseName -notmatch $Filter)) {
        continue
    }

    if ($Fast -and (Select-String -LiteralPath $testFile.FullName -Pattern 'babel_meme_game\.tscn' -Quiet)) {
        $skipped++
        continue
    }

    $scriptPath = "res://tests/$($testFile.Name)"
    Write-Host "==> $scriptPath"

    # Windows GUI Godot.exe returns immediately unless we wait on the process.
    $proc = Start-Process -FilePath $GodotBin -ArgumentList @(
        "--headless",
        "--path", $Root,
        "--script", $scriptPath
    ) -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -eq 0) {
        $passed++
    }
    else {
        $failures.Add($scriptPath) | Out-Null
    }
}

if (-not $SkipPython) {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        $python = Get-Command python3 -ErrorAction SilentlyContinue
    }

    if ($python) {
        $pyTests = Get-ChildItem -Path (Join-Path $Root "tests") -Filter "test_hand_tracker_*.py" -File |
            Sort-Object Name
        foreach ($pyTest in $pyTests) {
            if ($Filter -and ($pyTest.BaseName -notmatch $Filter)) {
                continue
            }

            $label = "python:$($pyTest.Name)"
            Write-Host "==> $label"
            & $python.Source $pyTest.FullName
            if ($LASTEXITCODE -eq 0) {
                $passed++
            }
            else {
                $failures.Add($label) | Out-Null
            }
        }
    }
    else {
        Write-Warning "Skipping Python tests: python not found."
    }
}

Write-Host ""
if ($Fast) {
    Write-Host "Mode: fast (skipped $skipped scene tests)"
}
else {
    Write-Host "Mode: full"
}
Write-Host "Passed: $passed"
Write-Host "Failed: $($failures.Count)"

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "  $failure"
    }
    exit 1
}

exit 0
