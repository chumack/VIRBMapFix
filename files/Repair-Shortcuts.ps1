# VIRBMapFix - rewrite/restore shortcuts that launch VirbEdit.exe.
# -Mode Install:   every shortcut pointing directly at VirbEdit.exe is repointed
#                  to the hidden on-demand launcher (server runs only while the
#                  program is open). Old arguments (e.g. a video file) are kept.
# -Mode Uninstall: reverts our shortcuts back to VirbEdit.exe.
# Run elevated (touches the common Start Menu); idempotent, safe to re-run.
# v1.3: no VBScript, no WScript.Shell COM (deprecated in Windows). Shortcuts
# are read/written via IShellLink (shell32/ole32) through Add-Type below.
# Shortcuts made by v1.2 (wscript.exe + VirbEdit-Launcher.vbs) are migrated.
param(
    [ValidateSet('Install', 'Uninstall')]
    [string]$Mode = 'Install'
)
$ErrorActionPreference = 'Continue'
$VirbExe = 'C:\Program Files\Garmin\VIRB Edit\VirbEdit.exe'
$LauncherExe = 'C:\ProgramData\VIRBMapFix\VirbEdit-Launcher.exe'
$LegacyMarker = 'VirbEdit-Launcher\.vbs'

# --- .lnk read/write without Windows Script Host (IShellLink via shell32) ---
if (-not ([System.Management.Automation.PSTypeName]'LnkUtil').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class LnkUtil
{
    [ComImport]
    [Guid("00021401-0000-0000-C000-000000000046")]
    private class CShellLink { }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("000214F9-0000-0000-C000-000000000046")]
    private interface IShellLinkW
    {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cch, IntPtr pfd, int fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cch);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cch);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cch);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cch, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, int dwReserved);
        void Resolve(IntPtr hwnd, int fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    [ComImport]
    [Guid("0000010b-0000-0000-C000-000000000046")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IPersistFile
    {
        void GetClassID(out Guid pClassID);
        [PreserveSig] int IsDirty();
        void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, int dwMode);
        void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, bool fRemember);
        void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
        void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
    }

    private const int STGM_READ = 0;
    private const int BUF = 4096;

    public static string[] ReadLink(string lnkPath)
    {
        CShellLink o = new CShellLink();
        try
        {
            ((IPersistFile)o).Load(lnkPath, STGM_READ);
            IShellLinkW l = (IShellLinkW)o;
            StringBuilder target = new StringBuilder(BUF);
            StringBuilder args = new StringBuilder(BUF);
            StringBuilder work = new StringBuilder(BUF);
            StringBuilder icon = new StringBuilder(BUF);
            l.GetPath(target, target.Capacity, IntPtr.Zero, 0);
            l.GetArguments(args, args.Capacity);
            l.GetWorkingDirectory(work, work.Capacity);
            string iconLoc;
            try
            {
                int iconIdx;
                l.GetIconLocation(icon, icon.Capacity, out iconIdx);
                iconLoc = icon.ToString() + "," + iconIdx;
            }
            catch { iconLoc = ""; }
            return new string[] { target.ToString(), args.ToString(), work.ToString(), iconLoc };
        }
        finally { Marshal.ReleaseComObject(o); }
    }

    public static void WriteLink(string lnkPath, string target, string args, string workDir, string iconLoc)
    {
        CShellLink o = new CShellLink();
        try
        {
            IPersistFile f = (IPersistFile)o;
            f.Load(lnkPath, STGM_READ);
            IShellLinkW l = (IShellLinkW)o;
            l.SetPath(target);
            l.SetArguments(args == null ? "" : args);
            if (workDir != null && workDir.Length > 0)
                l.SetWorkingDirectory(workDir);
            if (iconLoc != null && iconLoc.Length > 0)
            {
                int comma = iconLoc.LastIndexOf(',');
                int idx;
                if (comma > 0 && int.TryParse(iconLoc.Substring(comma + 1), out idx))
                    l.SetIconLocation(iconLoc.Substring(0, comma), idx);
                else
                    l.SetIconLocation(iconLoc, 0);
            }
            f.Save(lnkPath, true);
        }
        finally { Marshal.ReleaseComObject(o); }
    }
}
'@
}

function Get-Link([string]$Path) {
    $r = [LnkUtil]::ReadLink($Path)
    [pscustomobject]@{
        TargetPath       = [string]$r[0]
        Arguments        = [string]$r[1]
        WorkingDirectory = [string]$r[2]
        IconLocation     = [string]$r[3]
    }
}

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

$changed = 0
foreach ($file in Get-CandidateLinks) {
    try { $lnk = Get-Link $file.FullName } catch { continue }
    $target = ([string]$lnk.TargetPath).Trim()
    $args = [string]$lnk.Arguments
    if ($Mode -eq 'Install') {
        $realExe = $null
        $origArgs = ''
        if ($target -ieq $LauncherExe) {
            continue # already ours (v1.3+)
        } elseif ($args -match $LegacyMarker) {
            # v1.2 shortcut: wscript.exe //B //Nologo "launcher.vbs" "realExe" [rest]
            $m = [regex]::Match($args, 'VirbEdit-Launcher\.vbs"\s+"([^"]+)"\s*(.*)$')
            if (-not $m.Success) { continue }
            $realExe = $m.Groups[1].Value
            $origArgs = $m.Groups[2].Value.Trim()
        } elseif ($target -ieq $VirbExe) {
            $realExe = $VirbExe
            $origArgs = $args.Trim()
        } else {
            continue
        }
        $newArgs = '"' + $realExe + '"'
        if ($origArgs) { $newArgs += ' ' + $origArgs }
        $icon = ([string]$lnk.IconLocation).Trim()
        if (-not $icon -or $icon -eq ',0') { $icon = $realExe + ',0' }
        try {
            [LnkUtil]::WriteLink($file.FullName, $LauncherExe, $newArgs, (Split-Path $realExe), $icon)
        } catch { continue }
        $changed++
        Write-Output ("rewrote: " + $file.FullName)
    } else {
        $realExe = $null
        $restored = ''
        if ($target -ieq $LauncherExe) {
            # v1.3+ shortcut: launcher.exe "realExe" [rest]
            $m = [regex]::Match($args, '^\s*"([^"]+)"\s*(.*)$')
            if (-not $m.Success) { continue }
            $realExe = $m.Groups[1].Value
            $restored = $m.Groups[2].Value.Trim()
        } elseif ($args -match $LegacyMarker) {
            # v1.2 shortcut: '"vbs" "realExe" [rest]'
            $m = [regex]::Match($args, 'VirbEdit-Launcher\.vbs"\s+"([^"]+)"\s*(.*)$')
            if (-not $m.Success) { continue }
            $realExe = $m.Groups[1].Value
            $restored = $m.Groups[2].Value.Trim()
        } else {
            continue
        }
        try {
            [LnkUtil]::WriteLink($file.FullName, $realExe, $restored, (Split-Path $realExe), ($realExe + ',0'))
        } catch { continue }
        $changed++
        Write-Output ("restored: " + $file.FullName)
    }
}
Write-Output ("done, changed: " + $changed)
