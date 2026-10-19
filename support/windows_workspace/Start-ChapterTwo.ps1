$ErrorActionPreference = 'Stop'
$chapterProject = Join-Path $PSScriptRoot 'meme-game'
$chapterEngine = Join-Path $PSScriptRoot 'tools\godot-4.6.3\Godot_v4.6.3-stable_win64.exe'
$chapterOutput = Join-Path $PSScriptRoot 'outputs\chapter_two_preview'
$chapterProfile = Join-Path $chapterOutput 'profile'
if (-not (Test-Path -LiteralPath $chapterEngine)) { throw "Godot not found: $chapterEngine" }
if (-not (Test-Path -LiteralPath (Join-Path $chapterProject 'project.godot'))) { throw "Project not found: $chapterProject" }
New-Item -ItemType Directory -Path $chapterProfile -Force | Out-Null
$chapterOldAppData = $env:APPDATA
$chapterOldXdg = $env:XDG_DATA_HOME
try {
    $env:APPDATA = $chapterProfile
    $env:XDG_DATA_HOME = $chapterProfile
    $chapterArguments = @('--path', ('"{0}"' -f $chapterProject), '--log-file', ('"{0}"' -f (Join-Path $chapterOutput 'game.log')), '--rendering-method', 'gl_compatibility', '--resolution', '1440x900', '--script', 'res://tools/preview_chapter_two.gd')
    # This is the visible game window explicitly requested for interactive testing.
    $chapterProcess = Start-Process -FilePath $chapterEngine -WorkingDirectory $chapterProject -ArgumentList $chapterArguments -PassThru
    $chapterProcess.Id | Set-Content -LiteralPath (Join-Path $chapterOutput 'process-id.txt')
    Write-Output ("Chapter two launched: PID {0}" -f $chapterProcess.Id)
} finally {
    $env:APPDATA = $chapterOldAppData
    $env:XDG_DATA_HOME = $chapterOldXdg
}
