$ErrorActionPreference = 'Stop'
$previewProject = Join-Path $PSScriptRoot 'meme-game'
$previewEngine = Join-Path $PSScriptRoot 'tools\godot-4.6.3\Godot_v4.6.3-stable_win64.exe'
$previewOutput = Join-Path $PSScriptRoot 'outputs\floor_two_preview'
$previewProfile = Join-Path $previewOutput 'profile'
New-Item -ItemType Directory -Path $previewProfile -Force | Out-Null
$env:APPDATA = $previewProfile
$env:XDG_DATA_HOME = $previewProfile
$previewArguments = @('--path', ('"{0}"' -f $previewProject), '--log-file', ('"{0}"' -f (Join-Path $previewOutput 'game.log')), '--rendering-method', 'gl_compatibility', '--resolution', '1440x900', '--script', 'res://tools/preview_floor_two.gd')
# The user explicitly requested a visible interactive game window.
$previewProcess = Start-Process -FilePath $previewEngine -WorkingDirectory $previewProject -ArgumentList $previewArguments -PassThru
$previewProcess.Id | Set-Content -LiteralPath (Join-Path $previewOutput 'process-id.txt')
Write-Output ("Second-floor preview launched: PID {0}" -f $previewProcess.Id)
