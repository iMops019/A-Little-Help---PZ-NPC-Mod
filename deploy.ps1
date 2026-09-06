<#
    A Little Help - dev deploy

    Copies the mod into the Project Zomboid user folder and (by default) makes
    sure it is enabled + present in the mod-order list the "New Game" screen
    reads from, so you only have to click through the mod screens, never
    re-tick anything.

    There is no "build" for a PZ mod - the game reads the .lua files directly.
    "Deploy" just means: copy common/ into the right place.

    B42 discovery rule (from ZomboidFileSystem.getAllModFoldersAux): a folder in
    <user>/Zomboid/mods is only registered if it has common/mod.info or
    <version>/mod.info. A bare mod.info at the mod root is ignored for local
    mods. Hence the common/ layout.

    Usage:
      powershell -ExecutionPolicy Bypass -File deploy.ps1
      powershell -ExecutionPolicy Bypass -File deploy.ps1 -Saves latest
      powershell -ExecutionPolicy Bypass -File deploy.ps1 -Launch -Debug
      powershell -ExecutionPolicy Bypass -File deploy.ps1 -NoEnable

    Params:
      -Saves  none|latest|all   also add the mod to existing saves' mods.txt
                                (default: none - use a New Game to test)
      -Launch                    start Project Zomboid (console build) afterwards
      -Debug                     with -Launch, pass -debug (enables the in-game
                                 "Reload ALH lua" button and the debug menu)
      -NoEnable                  copy files only, don't touch any mod list
#>

param(
    [ValidateSet('none', 'latest', 'all')]
    [string]$Saves = 'none',
    [switch]$Launch,
    [switch]$Debug,
    [switch]$NoEnable
)

$ErrorActionPreference = 'Stop'

$MOD_ID   = 'ALittleHelp'
$src      = $PSScriptRoot
$zomboid  = 'C:\Users\conov\Zomboid'
$modDst   = Join-Path $zomboid "mods\$MOD_ID"
$pzBat    = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\ProjectZomboid64ShowConsole.bat'

function Write-Head($t) { Write-Host "`n$t" -ForegroundColor Cyan }

# --- UTF-8 (no BOM), CRLF - matches how PZ writes these files -----------------
function Save-PzList($path, [string[]]$lines) {
    $text = ($lines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# --- insert "mod = <id>," just before the mods{} block's closing brace -------
function Add-ModToList($path) {
    $leaf = Split-Path $path -Leaf
    if (-not (Test-Path $path)) {
        Write-Host "  . $leaf not found - skip (launch the game once to create it)" -ForegroundColor DarkYellow
        return
    }

    $lines = [System.IO.File]::ReadAllLines($path)
    foreach ($l in $lines) {
        if ($l -match "^\s*mod\s*=\s*$([regex]::Escape($MOD_ID))\s*,?\s*$") {
            Write-Host "  = $leaf already lists $MOD_ID"
            return
        }
    }

    $out = [System.Collections.Generic.List[string]]::new()
    $section = $null          # $null -> 'mods' -> 'maps'
    $done = $false
    foreach ($l in $lines) {
        $t = $l.Trim()
        if ($null -eq $section -and $t -eq 'mods') { $section = 'mods' }
        elseif ($section -eq 'mods' -and $t -eq 'maps') { $section = 'maps' }

        if ($section -eq 'mods' -and -not $done -and $t -eq '}') {
            $out.Add("    mod = $MOD_ID,")
            $done = $true
        }
        $out.Add($l)
    }

    if (-not $done) {
        Write-Host "  ! couldn't find a mods{} block in $leaf - not modified" -ForegroundColor Red
        return
    }
    Save-PzList $path $out
    Write-Host "  + added $MOD_ID to $leaf" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
Write-Head "1. Copy mod -> $modDst"
New-Item -ItemType Directory -Force -Path $modDst | Out-Null

# clean up a previous flat-layout deploy (media/ at the mod root)
if (Test-Path "$modDst\media") { Remove-Item "$modDst\media" -Recurse -Force }

# common/ is the whole payload (mod.info, poster.png, icon.png, media/)
robocopy "$src\common" "$modDst\common" /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed (exit $LASTEXITCODE)" }

# mod.info: PZ's parser is line-based; keep it CRLF no matter how git checked it
# out. Write it to common/ (required for discovery) and the root (belt + braces).
$info = [System.IO.File]::ReadAllText("$src\common\mod.info") -replace "`r?`n", "`r`n"
if ($info[-1] -ne "`n") { $info += "`r`n" }
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("$modDst\common\mod.info", $info, $utf8)
[System.IO.File]::WriteAllText("$modDst\mod.info", $info, $utf8)
foreach ($f in 'poster.png', 'icon.png') {
    if (Test-Path "$modDst\common\$f") { Copy-Item "$modDst\common\$f" "$modDst\$f" -Force }
}

if (-not (Test-Path "$modDst\common\mod.info")) {
    Write-Host "  ! common\mod.info missing - B42 will not discover the mod" -ForegroundColor Red
}
$fileCount = (Get-ChildItem "$modDst\common\media" -Recurse -File).Count
Write-Host "  copied common\ (mod.info, poster, $fileCount file(s) under media/)"

if (-not $NoEnable) {
    Write-Head "2. Enable in the New Game mod list"
    Add-ModToList (Join-Path $zomboid 'mods\default.txt')

    if ($Saves -ne 'none') {
        Write-Head "3. Add to existing saves ($Saves)"
        $saveDirs = Get-ChildItem "$zomboid\Saves" -Recurse -Depth 1 -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'mods.txt') }
        if ($Saves -eq 'latest') {
            $saveDirs = $saveDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        foreach ($d in $saveDirs) {
            Write-Host "  $($d.Name)"
            Add-ModToList (Join-Path $d.FullName 'mods.txt')
        }
        if (-not $saveDirs) { Write-Host "  (no saves with a mods.txt found)" }
    }
}

Write-Head "Done."
Write-Host @"
Next:
  - Launch PZ. New Game -> the mod screen already has 'A Little Help'
    ticked and in the load order; just Next through it.
  - In game: press G, or right-click the ground -> 'ALH NPC'.
  - Live log + Lua errors: the console window from
    ProjectZomboid64ShowConsole.bat, or $zomboid\console.txt
    (grep for [A Little Help]).
"@

if ($Launch) {
    $pzArgs = if ($Debug) { @('-debug') } else { @() }
    Write-Head ("Launching Project Zomboid{0}..." -f $(if ($Debug) { ' (-debug)' } else { '' }))
    if (Test-Path $pzBat) {
        Start-Process -FilePath $pzBat -WorkingDirectory (Split-Path $pzBat) -ArgumentList $pzArgs
    } else {
        Start-Process 'steam://rungameid/108600'
        if ($Debug) { Write-Host "  (Steam launch can't pass -debug - set '-debug' in Steam > Properties > Launch Options)" -ForegroundColor DarkYellow }
    }
}

exit 0
