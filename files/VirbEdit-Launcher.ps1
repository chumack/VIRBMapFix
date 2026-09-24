# VIRBMapFix on-demand launcher, part 2.
# Starts the local map server only while VIRB Edit is running, then stops it.
# Called from VirbEdit-Launcher.exe (shortcuts rewritten by the installer):
#   first argument = real VirbEdit.exe path, the rest = passthrough args.
# Called with no arguments (manual start) it uses the default install path.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RawArgs
)
$ErrorActionPreference = 'Continue'
$FixDir      = 'C:\ProgramData\VIRBMapFix'
$ServerPs1   = Join-Path $FixDir 'server.ps1'
$DefaultVirb = 'C:\Program Files\Garmin\VIRB Edit\VirbEdit.exe'
$LauncherLog = Join-Path $FixDir 'launcher.log'

function Write-LauncherLog([string]$text) {
    try { Add-Content -Path $LauncherLog -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $text) -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Test-Port80 {
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $handle = $client.BeginConnect('127.0.0.1', 80, $null, $null)
        $connected = $handle.AsyncWaitHandle.WaitOne(700)
        if ($connected -and $client.Connected) { $client.Close(); return $true }
        $client.Close()
    } catch {}
    return $false
}

function Get-ServerProcs {
    try {
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like '*VIRBMapFix*server.ps1*' }
    } catch { $null }
}

function Stop-OwnServer {
    foreach ($srv in Get-ServerProcs) {
        try { Stop-Process -Id $srv.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Show-Fatal([string]$text) {
    Write-LauncherLog("ERROR $text")
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [System.Windows.Forms.MessageBox]::Show($text, 'VIRBMapFix', 'OK', 'Error') | Out-Null
    } catch {}
}

# NOTE: -ArgumentList must be omitted (not @()) when there are no args:
# Windows PowerShell 5.1 fails to bind an empty array ("Cannot bind ... NULL").
function Start-VirbEdit([string]$exe, [string[]]$exeArgs) {
    $startParams = @{ FilePath = $exe; WorkingDirectory = (Split-Path $exe); PassThru = $true }
    if ($exeArgs -and $exeArgs.Count -gt 0) { $startParams.ArgumentList = $exeArgs }
    Start-Process @startParams
}

# 1. Real VirbEdit path + passthrough arguments.
$RealExe = $DefaultVirb
$PassArgs = @()
if ($RawArgs -and $RawArgs.Count -gt 0 -and $RawArgs[0]) {
    $RealExe = $RawArgs[0]
    if ($RawArgs.Count -gt 1) { $PassArgs = $RawArgs[1..($RawArgs.Count - 1)] }
}
if (-not (Test-Path $RealExe)) {
    Show-Fatal("VirbEdit not found:`n$RealExe")
    exit 1
}
if (-not (Test-Path $ServerPs1)) {
    # Server gone (partial uninstall?): still let VirbEdit start, maps just won't work.
    Write-LauncherLog('WARNING server.ps1 missing, starting VirbEdit without map fix')
    Start-VirbEdit $RealExe $PassArgs
    exit 0
}

# 2. Reuse running server or start our own (hidden, no console window).
$weStarted = $false
if ((Test-Port80) -and (Get-ServerProcs)) {
    Write-LauncherLog('server already running, reusing')
} else {
    Write-LauncherLog('starting server for VirbEdit')
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList '-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\VIRBMapFix\server.ps1"' `
        -WindowStyle Hidden
    $weStarted = $true
    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-Port80) { $ready = $true; break }
    }
    if ($ready) {
        Write-LauncherLog('server ready')
    } else {
        Write-LauncherLog('WARNING port 80 not responding, starting VirbEdit anyway')
    }
}

# 3. Run the real VirbEdit and wait until it is fully closed.
try {
    $proc = Start-VirbEdit $RealExe $PassArgs
    try { $proc.WaitForExit() } catch {}
} catch {
    if ($weStarted) { Stop-OwnServer }
    Show-Fatal("Failed to start VirbEdit:`n$($_.Exception.Message)")
    exit 1
}
# Cover child processes / second instances: wait while ANY VirbEdit is alive.
Start-Sleep -Seconds 2
while (Get-Process -Name 'VirbEdit' -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 2
}

# 4. Stop the server only if we started it and nobody needs it anymore.
if ($weStarted) {
    if (-not (Get-Process -Name 'VirbEdit' -ErrorAction SilentlyContinue)) {
        Write-LauncherLog('VirbEdit closed, stopping server')
        Start-Sleep -Seconds 1
        Stop-OwnServer
    } else {
        Write-LauncherLog('another VirbEdit still running, keeping server')
    }
} else {
    Write-LauncherLog('VirbEdit closed (server was external, not stopping)')
}
