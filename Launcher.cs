// Lockdown.exe - starts Lockdown.ps1 with no console window (and shows the Lockdown icon).
// Build it with Build-Launcher.ps1; Lockdown.bat does that automatically the first time.
//
//   Lockdown.exe [args]                  start the app (args are passed on, e.g. -Startup)
//   Lockdown.exe --run <script> [args]   run another script hidden and wait for it (used for the admin step)
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;

static class Launcher
{
    static string Quote(string s) { return "\"" + s.Replace("\"", "\\\"") + "\""; }

    [STAThread]
    static int Main(string[] args)
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                                         @"WindowsPowerShell\v1.0\powershell.exe");
        bool wait = args.Length >= 2 && args[0] == "--run";
        string script = wait ? args[1] : Path.Combine(dir, "Lockdown.ps1");
        string rest = string.Join(" ", args.Skip(wait ? 2 : 0).Select(Quote));

        var psi = new ProcessStartInfo(powershell,
            "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File " + Quote(script) + " " + rest);
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;     // no console, no terminal window
        psi.WorkingDirectory = dir;

        using (var p = Process.Start(psi))
        {
            if (!wait) return 0;
            p.WaitForExit();
            return p.ExitCode;
        }
    }
}
