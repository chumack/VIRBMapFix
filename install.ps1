# VIRBMapFix - установка патча карты для Garmin VIRB Edit
# Запускать через install.bat (с правами администратора).
# v1.3: скрытый лаунчер - нативный VirbEdit-Launcher.exe (без VBScript/WSH),
# на который установщик переписывает ярлыки. Фоновой задачи
# в планировщике, IFEO-перехвата и окон PowerShell при загрузке нет.
$ErrorActionPreference = 'Stop'
$Target = 'C:\ProgramData\VIRBMapFix'
$Src = Join-Path $PSScriptRoot 'files'
$IfeoKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VirbEdit.exe'

Write-Host '=== VIRBMapFix: установка ==='

# 1. Файлы
Write-Host '[1/6] Копирование файлов...'
New-Item -ItemType Directory -Force -Path $Target | Out-Null
Copy-Item (Join-Path $Src 'server.ps1') (Join-Path $Target 'server.ps1') -Force
Copy-Item (Join-Path $Src 'VirbEdit-Launcher.ps1') (Join-Path $Target 'VirbEdit-Launcher.ps1') -Force
$LauncherExeSrc = Join-Path $Src 'VirbEdit-Launcher.exe'
if (-not (Test-Path $LauncherExeSrc)) {
    # Нет готового лаунчера в пакете (разработка из исходников):
    # собрать штатным csc.exe из .NET Framework, Visual Studio не нужна.
    Write-Host 'Сборка VirbEdit-Launcher.exe...'
    $cs = Join-Path $PSScriptRoot 'src\VirbEdit-Launcher.cs'
    $csc = $null
    foreach ($c in @('C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe',
                     'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe')) {
        if (Test-Path $c) { $csc = $c; break }
    }
    if (-not $csc) { throw 'VirbEdit-Launcher.exe not found, csc.exe missing (needs .NET Framework 4.x)' }
    & $csc /nologo /optimize+ /target:winexe /out:$LauncherExeSrc $cs
    if ($LASTEXITCODE -ne 0) { throw 'Failed to compile VirbEdit-Launcher.exe' }
}
Copy-Item $LauncherExeSrc (Join-Path $Target 'VirbEdit-Launcher.exe') -Force
Remove-Item (Join-Path $Target 'VirbEdit-Launcher.vbs') -Force -ErrorAction SilentlyContinue # legacy v1.2
Copy-Item (Join-Path $Src 'Repair-Shortcuts.ps1') (Join-Path $Target 'Repair-Shortcuts.ps1') -Force
New-Item -ItemType Directory -Force -Path (Join-Path $Target 'www') | Out-Null
# Копируем СОДЕРЖИМОЕ www, а не папку целиком: иначе повторная установка
# поверх существующей создаёт вложенный www\www (Copy-Item dir в существующий dir).
Copy-Item (Join-Path $Src 'www\*') (Join-Path $Target 'www') -Recurse -Force

# 2. Реестр: заставить VIRB Edit использовать режим IE11 (Edge mode)
Write-Host '[2/6] Настройка реестра...'
$emu = 'HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION'
if (-not (Test-Path $emu)) { New-Item -Path $emu -Force | Out-Null }
New-ItemProperty -Path $emu -Name 'VirbEdit.exe' -Value 0x2ee1 -PropertyType DWord -Force | Out-Null
$emuCU = 'HKCU:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION'
if (-not (Test-Path $emuCU)) { New-Item -Path $emuCU -Force | Out-Null }
New-ItemProperty -Path $emuCU -Name 'VirbEdit.exe' -Value 0x2ee1 -PropertyType DWord -Force | Out-Null

# 3. hosts: направить static.garmincdn.com на локальный сервер
Write-Host '[3/6] Настройка hosts...'
$hosts = 'C:\Windows\System32\drivers\etc\hosts'
$lines = @()
if (Test-Path $hosts) { $lines = Get-Content $hosts }
$lines = @($lines | Where-Object { $_ -notmatch 'static\.garmincdn\.com\s*(#\s*VIRBMapFix)?\s*$' })
$lines += '127.0.0.1 static.garmincdn.com # VIRBMapFix'
Set-Content -Path $hosts -Value $lines -Encoding ASCII -Force

# 4. Разрешения http.sys, чтобы сервер работал без прав админа
Write-Host '[4/6] Настройка urlacl...'
& netsh http add urlacl url=http://127.0.0.1:80/ sddl="D:(A;;GX;;;S-1-5-32-545)" 2>&1 | Out-Null
& netsh http add urlacl url=http://localhost:80/ sddl="D:(A;;GX;;;S-1-5-32-545)" 2>&1 | Out-Null
& netsh http add urlacl url=http://[::1]:80/ sddl="D:(A;;GX;;;S-1-5-32-545)" 2>&1 | Out-Null
# Логи должны быть доступны на запись и без прав админа (иначе ошибки сервера не видны).
# На чистой установке логов ещё нет - icacls без совпадений пишет в stderr,
# что при $ErrorActionPreference='Stop' роняет установку, поэтому только при наличии файлов.
if (Get-ChildItem (Join-Path $Target '*.log') -ErrorAction SilentlyContinue) {
    & icacls "$Target\*.log" /grant "*S-1-5-32-545:M" 2>&1 | Out-Null
}

# 5. Запуск по требованию: убрать legacy-артефакты и переписать ярлыки на лаунчер.
# Ярлыки VIRB Edit (меню Пуск, рабочие столы, панель задач) теперь ведут в скрытый
# лаунчер: сервер стартует -> открывается программа -> сервер гаснет при закрытии.
# (Без IFEO-перехвата: отладчик IFEO перехватывал бы и запуск из самого лаунчера.)
Write-Host '[5/6] Настройка запуска по требованию...'
Unregister-ScheduledTask -TaskName 'VIRBMapFix' -Confirm:$false -ErrorAction SilentlyContinue
try {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*VIRBMapFix*server.ps1*' -or $_.CommandLine -like '*VirbEdit-Launcher.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}
if (Test-Path $IfeoKey) {
    Remove-ItemProperty -Path $IfeoKey -Name 'Debugger' -ErrorAction SilentlyContinue
    if (-not (Get-Item $IfeoKey | Select-Object -ExpandProperty Property)) { Remove-Item -Path $IfeoKey -Force -ErrorAction SilentlyContinue }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Target 'Repair-Shortcuts.ps1') -Mode Install

ipconfig /flushdns | Out-Null

# 6. Проверка: поднять сервер вручную на пару секунд (в фоне его больше нет).
Write-Host '[6/6] Проверка...'
Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\VIRBMapFix\server.ps1"' -WindowStyle Hidden
try {
    $ready = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $waiter = $tcp.BeginConnect('127.0.0.1', 80, $null, $null)
            if ($waiter.AsyncWaitHandle.WaitOne(500) -and $tcp.Connected) { $ready = $true }
            $tcp.Close()
            if ($ready) { break }
        } catch {}
    }
    if (-not $ready) {
        Write-Host 'ОШИБКА: сервер не поднялся. Проверьте, не занят ли порт 80 (netstat -ano | findstr :80)' -ForegroundColor Red
    } else {
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
    }
} finally {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*VIRBMapFix*server.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host 'Готово. Сервер теперь стартует только вместе с VIRB Edit и гаснет при закрытии.'
Write-Host 'Запускайте VIRB Edit как обычно (ярлык, панель задач) - фикс подхватится сам.'
Write-Host 'Проверка вручную: сначала откройте VIRB Edit, затем в браузере:'
Write-Host 'http://static.garmincdn.com/desktop-chandler/virbedit/maps/v8/google/index.html'
Write-Host 'Логи: C:\ProgramData\VIRBMapFix\server.log (сервер), launcher.log (лаунчер).'
Write-Host 'Удаление: запустите uninstall.bat'
