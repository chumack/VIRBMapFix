@echo off
rem VIRBMapFix - удаление патча. Self-elevates to admin.
chcp 65001 >nul
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
echo === VIRBMapFix: удаление ===
echo [1/7] Остановка сервера и лаунчеров...
schtasks /end /tn VIRBMapFix 2>nul
schtasks /delete /tn VIRBMapFix /f 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*VIRBMapFix*server.ps1*' -or $_.CommandLine -like '*VirbEdit-Launcher.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" 2>nul
echo [2/7] Возврат ярлыков на прямой запуск VirbEdit...
if exist "C:\ProgramData\VIRBMapFix\Repair-Shortcuts.ps1" powershell -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\VIRBMapFix\Repair-Shortcuts.ps1" -Mode Uninstall
echo [3/7] Удаление IFEO-перехвата...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$k='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VirbEdit.exe'; if (Test-Path $k) { Remove-ItemProperty -Path $k -Name 'Debugger' -ErrorAction SilentlyContinue; if (-not (Get-Item $k | Select-Object -ExpandProperty Property)) { Remove-Item -Path $k -Force } }" 2>nul
echo [4/7] Чистка hosts...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$h='C:\Windows\System32\drivers\etc\hosts'; if (Test-Path $h) { (Get-Content $h) | Where-Object { $_ -notmatch 'VIRBMapFix' } | Set-Content $h -Encoding ASCII -Force }; ipconfig /flushdns | Out-Null"
echo [5/7] Удаление urlacl...
netsh http delete urlacl url=http://127.0.0.1:80/ 2>nul
netsh http delete urlacl url=http://localhost:80/ 2>nul
netsh http delete urlacl url=http://[::1]:80/ 2>nul
echo [6/7] Удаление ярлыков лаунчера...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem 'C:\Users\*\Desktop\VIRB Edit Maps Fix.lnk','C:\Users\Public\Desktop\VIRB Edit Maps Fix.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue" 2>nul
echo [7/7] Удаление файлов...
rmdir /s /q "C:\ProgramData\VIRBMapFix" 2>nul
echo.
echo Готово. Запись реестра VirbEdit.exe (0x2ee1) оставлена - она безвредна.
echo Чтобы вернуть как было: удалите VirbEdit.exe из FEATURE_BROWSER_EMULATION.
pause
