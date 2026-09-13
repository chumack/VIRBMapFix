@echo off
rem VIRBMapFix - удаление патча. Self-elevates to admin.
chcp 65001 >nul
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
echo === VIRBMapFix: удаление ===
echo [1/4] Остановка сервера и удаление задачи...
schtasks /end /tn VIRBMapFix 2>nul
schtasks /delete /tn VIRBMapFix /f 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*VIRBMapFix*server.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" 2>nul
echo [2/4] Чистка hosts...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$h='C:\Windows\System32\drivers\etc\hosts'; if (Test-Path $h) { (Get-Content $h) | Where-Object { $_ -notmatch 'VIRBMapFix' } | Set-Content $h -Encoding ASCII -Force }; ipconfig /flushdns | Out-Null"
echo [3/4] Удаление urlacl...
netsh http delete urlacl url=http://127.0.0.1:80/ 2>nul
netsh http delete urlacl url=http://localhost:80/ 2>nul
echo [4/4] Удаление файлов...
rmdir /s /q "C:\ProgramData\VIRBMapFix" 2>nul
echo.
echo Готово. Запись реестра VirbEdit.exe (0x2ee1) оставлена - она безвредна.
echo Чтобы вернуть как было: удалите VirbEdit.exe из FEATURE_BROWSER_EMULATION.
pause
