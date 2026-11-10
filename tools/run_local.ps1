param(
    [switch]$Cafe,
    [string]$GodotPath
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $installed = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installed) { $GodotPath = $installed.Source }
    else { $GodotPath = Join-Path $env:USERPROFILE '.codex\tools\godot\4.7\Godot_v4.7-stable_win64.exe' }
}
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot 4.7 not found. Pass -GodotPath with the path to your Godot executable.'
}
# Import textures/fonts before a first direct script launch.
$importArgs = @('--headless', '--path', ('"' + $projectPath + '"'), '--editor', '--import')
$importProcess = Start-Process -FilePath $GodotPath -ArgumentList $importArgs -WorkingDirectory $projectPath -WindowStyle Hidden -Wait -PassThru
if ($importProcess.ExitCode -ne 0) { throw 'Godot resource import failed.' }
$gameArgs = @('--path', ('"' + $projectPath + '"'))
if ($Cafe) { $gameArgs += @('--script', 'res://tools/preview_cafe.gd') }
Start-Process -FilePath $GodotPath -ArgumentList $gameArgs -WorkingDirectory $projectPath
