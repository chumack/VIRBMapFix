@echo off
rem VIRBMapFix - build VirbEdit-Launcher.exe from src\VirbEdit-Launcher.cs
rem No Visual Studio needed: uses built-in .NET Framework csc.exe.
rem Run from repo root. Output: files\VirbEdit-Launcher.exe (winexe = no console flash).
setlocal
set "SRC=%~dp0VirbEdit-Launcher.cs"
set "OUT=%~dp0..\files\VirbEdit-Launcher.exe"
set "CSC="
if exist "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not defined CSC if exist "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "CSC=C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not defined CSC (
  echo ERROR: csc.exe not found. Install .NET Framework 4.x.
  exit /b 1
)
"%CSC%" /nologo /optimize+ /target:winexe /out:"%OUT%" "%SRC%"
if errorlevel 1 exit /b 1
echo Built: %OUT%
