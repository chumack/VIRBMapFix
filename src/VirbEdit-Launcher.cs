// VIRBMapFix on-demand launcher, part 1 (no-console entry point).
// Replaces VirbEdit-Launcher.vbs (removed: VBScript is deprecated in Windows).
// Shortcuts to VIRB Edit point here, so every launch goes through the hidden
// PowerShell launcher:
//   VirbEdit-Launcher.exe "<real VirbEdit.exe>" [args...]
// Everything is forwarded to VirbEdit-Launcher.ps1, fully hidden.
// Launched without arguments it just calls the ps1 (which uses the default path).
// Build: src\build-launcher.bat (no VS needed, uses built-in .NET csc.exe).
// Target must be winexe so no console window flashes.
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

static class VirbEditLauncher
{
    const string FixDir = @"C:\ProgramData\VIRBMapFix";
    const string Ps1Name = "VirbEdit-Launcher.ps1";

    [STAThread]
    static int Main()
    {
        try
        {
            string exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            string ps1 = Path.Combine(exeDir, Ps1Name);
            if (!File.Exists(ps1))
                ps1 = Path.Combine(FixDir, Ps1Name);

            string system = Environment.GetEnvironmentVariable("SystemRoot");
            string powershell = (system != null)
                ? Path.Combine(system, @"System32\WindowsPowerShell\v1.0\powershell.exe")
                : "powershell.exe";
            if (!File.Exists(powershell))
                powershell = "powershell.exe"; // fallback to PATH

            StringBuilder cmd = new StringBuilder();
            cmd.Append("-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass -WindowStyle Hidden -File ");
            cmd.Append(QuoteArg(ps1));
            string[] argv = Environment.GetCommandLineArgs();
            for (int i = 1; i < argv.Length; i++)
            {
                cmd.Append(' ');
                cmd.Append(QuoteArg(argv[i]));
            }

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = powershell;
            psi.Arguments = cmd.ToString();
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WindowStyle = ProcessWindowStyle.Hidden;
            Process.Start(psi); // async, like WshShell.Run(..., 0, False)
            return 0;
        }
        catch (Exception ex)
        {
            try
            {
                MessageBox.Show("VIRBMapFix launcher failed:\n" + ex.Message,
                    "VIRBMapFix", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            catch { }
            return 1;
        }
    }

    // Quote one argument per CommandLineToArgvW / .NET rules.
    static string QuoteArg(string s)
    {
        if (s.Length == 0)
            return "\"\"";
        bool need = s.IndexOfAny(new char[] { ' ', '\t', '"', '\n', '\v' }) >= 0;
        if (!need)
            return s;
        StringBuilder b = new StringBuilder();
        b.Append('"');
        int slashes = 0;
        foreach (char c in s)
        {
            if (c == '\\')
            {
                slashes++;
            }
            else if (c == '"')
            {
                for (int i = 0; i < slashes * 2 + 1; i++) b.Append('\\');
                b.Append('"');
                slashes = 0;
            }
            else
            {
                for (int i = 0; i < slashes; i++) b.Append('\\');
                slashes = 0;
                b.Append(c);
            }
        }
        for (int i = 0; i < slashes * 2; i++) b.Append('\\');
        b.Append('"');
        return b.ToString();
    }
}
