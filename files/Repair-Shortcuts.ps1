# VIRBMapFix - rewrite/restore shortcuts that launch VirbEdit.exe.
# -Mode Install:   every shortcut pointing directly at VirbEdit.exe is repointed
#                  to the hidden on-demand launcher (server runs only while the
#                  program is open). Old arguments (e.g. a video file) are kept.
# -Mode Uninstall: reverts our shortcuts back to VirbEdit.exe.
# Run elevated (touches the common Start Menu); idempotent, safe to re-run.
param(
    [ValidateSet('Install', 'Uninstall')]
    [string]$Mode = 'Install'
)
$ErrorActionPreference = 'Continue'
$VirbExe = 'C:\Program Files\Garmin\VIRB Edit\VirbEdit.exe'
$LauncherVbs = 'C:\ProgramData\VIRBMapFix\VirbEdit-Launcher.vbs'
$WScriptExe = Join-Path $env:SystemRoot 'System32\wscript.exe'

function Get-CandidateLinks {
    $dirs = @(
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Garmin'),
        (Join-Path $env:PUBLIC 'Desktop')
    )
    foreach ($profileDir in (Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue)) {
        $dirs += (Join-Path $profileDir.FullName 'Desktop')
        $dirs += (Join-Path $profileDir.FullName 'AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
        $dirs += (Join-Path $profileDir.FullName 'AppData\Roaming\Microsoft\Internet Explorer\Quick Launch')
    }
    $seen = @{}
    foreach ($dir in $dirs) {
        foreach ($lnk in (Get-ChildItem (Join-Path $dir '*.lnk') -ErrorAction SilentlyContinue)) {
            if (-not $seen.ContainsKey($lnk.FullName)) { $seen[$lnk.FullName] = $true; $lnk }
        }
    }
}

$shellObj = New-Object -ComObject WScript.Shell
$changed = 0
foreach ($file in Get-CandidateLinks) {
    try { $lnk = $shellObj.CreateShortcut($file.FullName) } catch { continue }
    $target = ([string]$lnk.TargetPath).Trim()
    $args = [string]$lnk.Arguments
    if ($Mode -eq 'Install') {
        $isOurs = $args -match 'VirbEdit-Launcher\.vbs'
        $isVirb = $target -ieq $VirbExe
        if (-not $isVirb -or $isOurs) { continue }
        $newArgs = '//B //Nologo "' + $LauncherVbs + '" "' + $VirbExe + '"'
        if ($args.Trim()) { $newArgs += ' ' + $args.Trim() }
        $lnk.TargetPath = $WScriptExe
        $lnk.Arguments = $newArgs
        $lnk.WorkingDirectory = Split-Path $VirbExe
        if (-not ([string]$lnk.IconLocation).Trim()) { $lnk.IconLocation = $VirbExe + ',0' }
        $lnk.Save()
        $changed++
        Write-Output ("rewrote: " + $file.FullName)
    } else {
        if ($args -notmatch 'VirbEdit-Launcher\.vbs') { continue }
        # Everything after our '"vbs" "exe"' prefix belonged to the original shortcut.
        $restored = ''
        $matchRes = [regex]::Match($args, 'VirbEdit-Launcher\.vbs"\s+"[^"]+"\s*(.*)$')
        if ($matchRes.Success) { $restored = $matchRes.Groups[1].Value.Trim() }
        $lnk.TargetPath = $VirbExe
        $lnk.Arguments = $restored
        $lnk.WorkingDirectory = Split-Path $VirbExe
        $lnk.IconLocation = $VirbExe + ',0'
        $lnk.Save()
        $changed++
        Write-Output ("restored: " + $file.FullName)
    }
}
Write-Output ("done, changed: " + $changed)
