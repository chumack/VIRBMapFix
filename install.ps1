# VIRBMapFix - установка патча карты для Garmin VIRB Edit
# Запускать через install.bat (с правами администратора).
$ErrorActionPreference = 'Stop'
$Target = 'C:\ProgramData\VIRBMapFix'
$Src = Join-Path $PSScriptRoot 'files'

Write-Host '=== VIRBMapFix: установка ==='

# 1. Файлы
Write-Host '[1/5] Копирование файлов...'
New-Item -ItemType Directory -Force -Path $Target | Out-Null
Copy-Item (Join-Path $Src 'server.ps1') (Join-Path $Target 'server.ps1') -Force
Copy-Item (Join-Path $Src 'www') (Join-Path $Target 'www') -Recurse -Force

# 2. Реестр: заставить VIRB Edit использовать режим IE11 (Edge mode)
Write-Host '[2/5] Настройка реестра...'
$emu = 'HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION'
if (-not (Test-Path $emu)) { New-Item -Path $emu -Force | Out-Null }
New-ItemProperty -Path $emu -Name 'VirbEdit.exe' -Value 0x2ee1 -PropertyType DWord -Force | Out-Null
$emuCU = 'HKCU:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION'
if (-not (Test-Path $emuCU)) { New-Item -Path $emuCU -Force | Out-Null }
New-ItemProperty -Path $emuCU -Name 'VirbEdit.exe' -Value 0x2ee1 -PropertyType DWord -Force | Out-Null

# 3. hosts: направить static.garmincdn.com на локальный сервер
Write-Host '[3/5] Настройка hosts...'
$hosts = 'C:\Windows\System32\drivers\etc\hosts'
$lines = @()
if (Test-Path $hosts) { $lines = Get-Content $hosts }
$lines = @($lines | Where-Object { $_ -notmatch 'static\.garmincdn\.com\s*(#\s*VIRBMapFix)?\s*$' })
$lines += '127.0.0.1 static.garmincdn.com # VIRBMapFix'
Set-Content -Path $hosts -Value $lines -Encoding ASCII -Force

# 4. Разрешения http.sys, чтобы сервер работал без прав админа
Write-Host '[4/5] Настройка urlacl...'
& netsh http add urlacl url=http://127.0.0.1:80/ sddl="D:(A;;GX;;;S-1-5-32-545)" 2>&1 | Out-Null
& netsh http add urlacl url=http://localhost:80/ sddl="D:(A;;GX;;;S-1-5-32-545)" 2>&1 | Out-Null

# 5. Автозапуск сервера
Write-Host '[5/5] Настройка автозапуска...'
Unregister-ScheduledTask -TaskName 'VIRBMapFix' -Confirm:$false -ErrorAction SilentlyContinue
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\ProgramData\VIRBMapFix\server.ps1'
$triggers = @((New-ScheduledTaskTrigger -AtStartup), (New-ScheduledTaskTrigger -AtLogOn -User $user))
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Register-ScheduledTask -TaskName 'VIRBMapFix' -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Description 'VIRB Edit map fix: local server for static.garmincdn.com' -Force | Out-Null

ipconfig /flushdns | Out-Null
Start-ScheduledTask -TaskName 'VIRBMapFix' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

# Проверка
try {
    $r = Invoke-WebRequest -Uri 'http://static.garmincdn.com/desktop-chandler/virbedit/maps/v8/google/index.html' -UseBasicParsing -TimeoutSec 10
    if ($r.StatusCode -eq 200 -and $r.Content -match 'map-canvas') {
        Write-Host 'OK: локальный сервер отвечает, карта подменяется.' -ForegroundColor Green
    } else {
        Write-Host 'ВНИМАНИЕ: сервер отвечает, но страница неожиданная. Проверьте server.log' -ForegroundColor Yellow
    }
} catch {
    Write-Host "ОШИБКА: сервер не отвечает: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Проверьте, не занят ли порт 80 другой программой (netstat -ano | findstr :80)'
}

Write-Host ''
Write-Host 'Готово. Перезапустите VIRB Edit и откройте G-Metrix журнал.'
Write-Host 'Проверка вручную: http://static.garmincdn.com/desktop-chandler/virbedit/maps/v8/google/index.html'
Write-Host 'Удаление: запустите uninstall.bat'
