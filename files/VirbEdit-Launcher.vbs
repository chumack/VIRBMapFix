' VIRBMapFix on-demand launcher, part 1 (no-console entry point).
' Shortcuts to VIRB Edit point here (rewritten by the installer), so every
' launch goes through the hidden PowerShell launcher below:
'   wscript.exe //B "C:\ProgramData\VIRBMapFix\VirbEdit-Launcher.vbs" "<real VirbEdit.exe>" [args...]
' Everything is forwarded to the PowerShell launcher, fully hidden (0 = hide window).
' Launched manually without arguments it just starts the default VirbEdit path.
Option Explicit
Dim shellObj, cmdLine, idx
Set shellObj = CreateObject("Wscript.Shell")
cmdLine = "powershell.exe -NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\ProgramData\VIRBMapFix\VirbEdit-Launcher.ps1"""
For idx = 0 To WScript.Arguments.Count - 1
    cmdLine = cmdLine & " """ & WScript.Arguments(idx) & """"
Next
shellObj.Run cmdLine, 0, False
