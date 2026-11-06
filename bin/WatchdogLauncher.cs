using System;
using System.Diagnostics;
using System.IO;

internal static class Program
{
    private static void Main()
    {
        try
        {
            string dir = AppDomain.CurrentDomain.BaseDirectory;
            string ps1 = Path.Combine(dir, "watchdog.ps1");
            if (!File.Exists(ps1)) return;
            string sysRoot = Environment.GetFolderPath(Environment.SpecialFolder.System);
            string psExe = Path.Combine(sysRoot, @"WindowsPowerShell\v1.0\powershell.exe");
            var psi = new ProcessStartInfo
            {
                FileName = psExe,
                Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + ps1 + "\"",
                CreateNoWindow = true,
                UseShellExecute = false,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            Process p = Process.Start(psi);
            if (p != null) p.WaitForExit(60000);
        }
        catch { }
    }
}