# Build a shareable zip of one map.
#
#   ./package.ps1 gauntlet   ->  dist/gauntlet.zip
#
# Ships only the named map, a cheats-free override.cfg, and the loader.
# Leaves out reference/, which holds artwork extracted from the game.
param([Parameter(Position = 0)][string]$Map)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $Map -or -not (Test-Path (Join-Path $here "mods/$Map/level.json"))) {
    $avail = (Get-ChildItem (Join-Path $here 'mods') -Directory).Name -join ', '
    [Console]::Error.WriteLine('usage: package.ps1 <map-folder>')
    [Console]::Error.WriteLine("available: $avail")
    exit 1
}

$out   = Join-Path $here "dist/$Map.zip"
$stage = Join-Path $here 'dist/.stage'

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $stage 'mods') -Force | Out-Null
Copy-Item (Join-Path $here 'mod_loader.gd')   $stage
Copy-Item (Join-Path $here 'dist/INSTALL.md') $stage
Copy-Item (Join-Path $here 'install.sh')  $stage
Copy-Item (Join-Path $here 'install.ps1') $stage
Copy-Item (Join-Path $here "mods/$Map") (Join-Path $stage "mods/$Map") -Recurse
Get-ChildItem (Join-Path $stage "mods/$Map") -Filter *.bak | Remove-Item -Force

# cheats deliberately omitted from the shared copy.
# Written through .NET so the encoding does not depend on the PowerShell
# version: 5.1's Out-File defaults to UTF-16 and Set-Content to ANSI, either
# of which can stop Godot reading the file.
$cfg = "[autoload]`n`nModLoader=`"*user://mod_loader.gd`"`n"
[System.IO.File]::WriteAllText((Join-Path $stage 'override.cfg'), $cfg,
    (New-Object System.Text.UTF8Encoding $false))

if (Test-Path $out) { Remove-Item $out -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $out -Force
Remove-Item $stage -Recurse -Force
Write-Output $out
