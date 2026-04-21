# Build pixel-agents-lua.exe — fuse the runtime Lua into a Love2D binary and
# stage the DLLs + data files (assets, layouts, hooks) alongside it.
#
# Output layout:
#   dist/pixel-agents-lua/
#     pixel-agents-lua.exe      (fused love.exe + game code)
#     *.dll                     (Love2D's SDL2/OpenAL/etc.)
#     license.txt               (Love2D's license — required by redistribution)
#     assets/                   (PNGs copied from webview-ui/public/assets)
#     layouts/                  (Lua layout files, user-editable)
#     hooks/                    (claude-hook.ps1 template)
#     README-dist.txt
#
# Optional: -Zip flag also creates dist/pixel-agents-lua.zip.
#
# Run: pwsh scripts/build-exe.ps1 [-LovePath "C:\Program Files\LOVE"] [-Zip]

param(
    [string]$LovePath = "C:\Program Files\LOVE",
    [switch]$Zip,
    [switch]$Console   # Fuse lovec.exe instead of love.exe so stdout attaches
)

$ErrorActionPreference = 'Stop'

# Resolve paths relative to this script's parent (the pixel-agents-lua/ root)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$GameRoot  = Resolve-Path (Join-Path $ScriptDir '..')
$RepoRoot  = Resolve-Path (Join-Path $GameRoot '..')
$DistRoot  = Join-Path $GameRoot 'dist'
$StageDir  = Join-Path $DistRoot 'pixel-agents-lua'

Write-Host "[build] GameRoot = $GameRoot"
Write-Host "[build] LovePath = $LovePath"

if (-not (Test-Path (Join-Path $LovePath 'love.exe'))) {
    throw "love.exe not found at $LovePath. Install Love2D 11.5 or pass -LovePath."
}

# --- 1. Clean dist ---
if (Test-Path $DistRoot) { Remove-Item -Recurse -Force $DistRoot }
New-Item -ItemType Directory -Path $StageDir | Out-Null

# --- 2. Build the .love archive (only runtime code, not data) ---
# Contents: conf.lua, main.lua, src/ — anything that uses require() at runtime.
# Data (assets/layouts/hooks) ships beside the .exe so users can swap PNGs or
# edit layouts without repacking.
$LoveFile = Join-Path $DistRoot 'game.love'
$LoveZip  = Join-Path $DistRoot 'game.zip'   # Compress-Archive only accepts .zip
$LoveStage = Join-Path $DistRoot '_love_stage'
if (Test-Path $LoveStage) { Remove-Item -Recurse -Force $LoveStage }
New-Item -ItemType Directory -Path $LoveStage | Out-Null

Copy-Item (Join-Path $GameRoot 'conf.lua') $LoveStage
Copy-Item (Join-Path $GameRoot 'main.lua') $LoveStage
Copy-Item -Recurse (Join-Path $GameRoot 'src') (Join-Path $LoveStage 'src')

# Zip with entries at the root (Compress-Archive puts entries relative to
# the items given; passing the directory contents via wildcard).
$ZipItems = Get-ChildItem -Path $LoveStage
Compress-Archive -Path $ZipItems.FullName -DestinationPath $LoveZip -Force
Move-Item -Force $LoveZip $LoveFile
Remove-Item -Recurse -Force $LoveStage
Write-Host "[build] wrote $LoveFile ($((Get-Item $LoveFile).Length) bytes)"

# --- 3. Fuse love.exe + game.love -> pixel-agents-lua.exe ---
$FusedExe = Join-Path $StageDir 'pixel-agents-lua.exe'
$LoveExeName = if ($Console) { 'lovec.exe' } else { 'love.exe' }
$LoveExe  = Join-Path $LovePath $LoveExeName
cmd.exe /c "copy /b `"$LoveExe`" + `"$LoveFile`" `"$FusedExe`"" | Out-Null
if (-not (Test-Path $FusedExe)) { throw "fuse failed: $FusedExe not produced" }
Remove-Item $LoveFile
Write-Host "[build] fused -> $FusedExe ($((Get-Item $FusedExe).Length) bytes)"

# --- 4. Copy runtime DLLs + license ---
$DllNames = @('SDL2.dll','OpenAL32.dll','love.dll','lua51.dll','mpg123.dll','msvcp120.dll','msvcr120.dll')
foreach ($dll in $DllNames) {
    $src = Join-Path $LovePath $dll
    if (-not (Test-Path $src)) {
        Write-Warning "missing $dll in $LovePath — skipping"
        continue
    }
    Copy-Item $src $StageDir
}
Copy-Item (Join-Path $LovePath 'license.txt') (Join-Path $StageDir 'license-love2d.txt')

# --- 5. Copy data dirs next to the exe ---
$AssetsSrc = Join-Path $RepoRoot 'webview-ui\public\assets'
if (-not (Test-Path $AssetsSrc)) {
    throw "assets source not found: $AssetsSrc"
}
Copy-Item -Recurse $AssetsSrc (Join-Path $StageDir 'assets')
Copy-Item -Recurse (Join-Path $GameRoot 'layouts') (Join-Path $StageDir 'layouts')
Copy-Item -Recurse (Join-Path $GameRoot 'hooks')   (Join-Path $StageDir 'hooks')

# --- 6. README for the distribution ---
$ReadmeDist = @'
Pixel Agents Lua — Windows distribution
========================================

Run: double-click pixel-agents-lua.exe (or from PowerShell: .\pixel-agents-lua.exe)

First run:
  - The app watches %USERPROFILE%\.claude\projects\<project-hash>\ for JSONL
    transcripts. Start a Claude Code session in the project whose path hashes
    to the one shown on the boot log.
  - To use hooks mode (lower latency), create
    %USERPROFILE%\.pixel-agents-lua\config.lua with:
        return { hooksEnabled = true }
    and relaunch. Hooks are removed on graceful quit.

Files:
  pixel-agents-lua.exe     Fused Love2D + game code.
  *.dll                    Love2D runtime.
  assets/                  PNG sprites (editable — replace and restart).
  layouts/                 Lua office layouts (editable).
  hooks/claude-hook.ps1    PowerShell script copied to user dir when hooks on.
  license-love2d.txt       Love2D's zlib license.

Character art (assets/characters/char_*.png) is from JIK-A-4's Metro City
pack on itch.io and is NOT covered by this project's license — check the
asset pack's terms before redistributing.
'@
Set-Content -Path (Join-Path $StageDir 'README-dist.txt') -Value $ReadmeDist -Encoding UTF8

# --- 7. Optional outer zip ---
if ($Zip) {
    $ZipOut = Join-Path $DistRoot 'pixel-agents-lua.zip'
    Compress-Archive -Path (Join-Path $StageDir '*') -DestinationPath $ZipOut -Force
    Write-Host "[build] wrote $ZipOut ($((Get-Item $ZipOut).Length) bytes)"
}

$FinalSize = (Get-ChildItem -Recurse $StageDir | Measure-Object -Property Length -Sum).Sum
Write-Host "[build] done: $StageDir ($([math]::Round($FinalSize/1MB,2)) MB)"
