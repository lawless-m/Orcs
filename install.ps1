# Install the custom-map loader for "Sir, We Have an Orc Problem".
#
# Most people should just double-click install.bat instead of running this.
#
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Editor -Cheats
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
#
# The -ExecutionPolicy is needed because Windows blocks downloaded scripts.
# Nothing belonging to the game is modified: one config file goes beside the
# executable, and the loader and your maps go in the save folder.
param(
    [string]$GamePath,     # skip the search and use this folder
    [switch]$Editor,       # also install the map painter (F11)
    [switch]$Cheats,       # dev menu, and an Unlock button on every level
    [switch]$Uninstall,
    [switch]$Interactive   # ask instead; this is what install.bat uses
)

if ($Interactive) {
    Write-Output ''
    Write-Output 'Custom maps for "Sir, We Have an Orc Problem".'
    Write-Output 'Nothing belonging to the game is changed, and you can undo all of this later.'
    Write-Output ''
    $Editor = (Read-Host 'Do you want the map editor too, so you can draw your own maps? [y/N]') -match '^\s*[Yy]'
    $Cheats = (Read-Host 'Unlock the new map now, instead of finishing the game first? [y/N]') -match '^\s*[Yy]'
    Write-Output ''
}

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$GameName = 'Sir, We Have an Orc Problem'

function Find-Game {
    if ($GamePath) { return $GamePath }
    $roots = @()
    if ($IsWindows -or $null -eq $IsWindows) {
        $reg = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
        if ($reg.SteamPath) { $roots += $reg.SteamPath }
        $roots += "${env:ProgramFiles(x86)}\Steam"
    } else {
        $roots += "$HOME/.local/share/Steam", "$HOME/.steam/steam"
    }
    # every library, not just the default one
    foreach ($r in @($roots)) {
        $vdf = Join-Path $r 'steamapps/libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"(.+?)"')) {
                $roots += $m.Groups[1].Value -replace '\\\\', '\'
            }
        }
    }
    foreach ($r in ($roots | Where-Object { $_ } | Select-Object -Unique)) {
        $dir = Join-Path $r "steamapps/common/$GameName"
        if ((Test-Path (Join-Path $dir 'swhaop.exe')) -or
            (Test-Path (Join-Path $dir 'swhaop.x86_64'))) { return $dir }
    }
    return $null
}

function Get-UserDir {
    # the game sets use_custom_user_dir, so Godot uses the project name
    if ($IsWindows -or $null -eq $IsWindows) { return Join-Path $env:APPDATA $GameName }
    if ($IsMacOS) { return Join-Path $HOME "Library/Application Support/$GameName" }
    $base = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { "$HOME/.local/share" }
    return Join-Path $base $GameName
}

$game = Find-Game
if (-not $game) {
    [Console]::Error.WriteLine("Could not find $GameName.")
    [Console]::Error.WriteLine("In Steam: right-click the game, Manage, Browse local files,")
    [Console]::Error.WriteLine("then re-run with -GamePath ""<that folder>""")
    exit 1
}
$user = Get-UserDir
Write-Output "game : $game"
Write-Output "saves: $user"

if ($Uninstall) {
    foreach ($f in @((Join-Path $game 'override.cfg'),
                     (Join-Path $user 'mod_loader.gd'),
                     (Join-Path $user 'editor.gd'))) {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Output "removed $f" }
    }
    Write-Output "Your maps in $(Join-Path $user 'mods') and your saves were left alone."
    exit 0
}

# override.cfg, built to match the switches. Written through .NET so the
# encoding does not depend on the PowerShell version: 5.1's Out-File defaults
# to UTF-16 and Set-Content to ANSI, either of which can stop Godot reading it.
$lines = @()
if ($Cheats) { $lines += '_custom_features="steam,cheats"', '' }
$lines += '[autoload]', '', 'ModLoader="*user://mod_loader.gd"'
if ($Editor) { $lines += 'MapEditor="*user://editor.gd"' }
[System.IO.File]::WriteAllText((Join-Path $game 'override.cfg'),
    ($lines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
Write-Output "wrote override.cfg"

New-Item -ItemType Directory -Path $user -Force | Out-Null
Copy-Item (Join-Path $here 'mod_loader.gd') $user -Force
Write-Output "copied mod_loader.gd"

if ($Editor) {
    $ed = Join-Path $here 'editor.gd'
    if (Test-Path $ed) {
        Copy-Item $ed $user -Force
        Write-Output "copied editor.gd -- press F11 in game"
    } else {
        [Console]::Error.WriteLine("-Editor asked for, but editor.gd is not in this folder.")
        [Console]::Error.WriteLine("It ships with the repository, not the player download:")
        [Console]::Error.WriteLine("  https://github.com/lawless-m/Orcs")
    }
}

# maps are copied in, never over: yours are not ours to replace
$src = Join-Path $here 'mods'
if (Test-Path $src) {
    New-Item -ItemType Directory -Path (Join-Path $user 'mods') -Force | Out-Null
    foreach ($m in Get-ChildItem $src -Directory) {
        $dest = Join-Path $user "mods/$($m.Name)"
        if (Test-Path $dest) {
            Write-Output "kept your existing mods/$($m.Name)"
        } else {
            Copy-Item $m.FullName $dest -Recurse
            Get-ChildItem $dest -Filter *.bak | Remove-Item -Force
            Write-Output "installed map $($m.Name)"
        }
    }
}

Write-Output ''
Write-Output 'Done. Start the game through Steam; the map is at the bottom of the Levels list.'
if (-not $Cheats) { Write-Output 'It unlocks once you have survived Level 6.2 (-Cheats gives an Unlock button).' }
