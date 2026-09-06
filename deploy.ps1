# A Little Help - copy the mod into the Project Zomboid mods folder for testing.
# Run from anywhere:   powershell -ExecutionPolicy Bypass -File deploy.ps1
#
# Only the actual mod payload (mod.info + media/) is copied. Repo files
# (docs, README, git, this script) are left behind.

$src = $PSScriptRoot
$dst = "C:\Users\conov\Zomboid\mods\ALittleHelp"

Write-Host "Deploying A Little Help"
Write-Host "  from $src"
Write-Host "  to   $dst"

New-Item -ItemType Directory -Force -Path $dst | Out-Null

# media/ : mirror (adds new files, deletes removed ones)
robocopy "$src\media" "$dst\media" /MIR /NFL /NDL /NJH /NJS /NP
$code = $LASTEXITCODE
if ($code -ge 8) { Write-Error "robocopy failed (exit $code)"; exit $code }

# mod.info : single file
Copy-Item "$src\mod.info" "$dst\mod.info" -Force

Write-Host ""
Write-Host "Done. In Project Zomboid: enable 'A Little Help' in the Mods menu,"
Write-Host "then load a save and press G. Watch C:\Users\conov\Zomboid\console.txt for [A Little Help] lines."
exit 0
