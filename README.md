# Lockdown

A small Windows app that locks distracting applications and websites for a study session, and is hard to get around once a session starts.

It's a compact, always-on-top miniplayer: pick a session length, choose what to lock, press Start.

## Features

- **Lock applications.** Pick from your installed and running apps (with their icons) or browse to any `.exe`. Locked apps are closed the moment they open, and a notice tells you how long is left.
- **Lock websites** in Chrome, Edge, Brave and Firefox, two ways:
  - **Allow Only**: everything is blocked except the sites you list (for example WhatsApp, Google Drive, Google Classroom).
  - **Block List**: only the sites you list are blocked.
  - Type a plain name like `youtube` and every domain that site uses is covered (youtube.com, youtu.be, its video servers, and so on). Anything else becomes `name.com`, and full domains work too.
- **Strict mode.** Once a session starts it can't be stopped early, and the usual tricks don't work (see below).
- **Your own session lengths.** Press **+** and type `25`, `45`, `1h30`, and so on. Right-click a length to remove it.
- **Size per monitor.** The magnifier button scales the window (Auto, 100% to 200%), remembered separately for each screen resolution.
- Smooth countdown ring, dark theme, pin to keep it on top, its own taskbar icon, and it lives in the system tray while a session runs.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (built into Windows, nothing to install)
- An administrator account for strict mode and website blocking (you approve one Windows prompt per session)

## Run it

1. Download or clone this repository.
2. Double-click **`Lockdown.bat`** the first time. It builds `Lockdown.exe` from [`Launcher.cs`](Launcher.cs) using the C# compiler that ships with Windows, then starts Lockdown.
3. From then on, open **`Lockdown.exe`**. It starts Lockdown with no console window.

To pin it, start Lockdown, right-click its taskbar button and choose **Pin to taskbar**.

`Lockdown.exe` isn't checked in, so there's no prebuilt binary to trust: it's built on your PC from the short source file. To rebuild it yourself, run `Build-Launcher.ps1`. You can also skip it and run the script directly:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -STA -File Lockdown.ps1
```

## How strict mode works

When a session starts, Lockdown asks for admin permission once and sets up a hidden Windows scheduled task, **Lockdown Guard**, that runs as `SYSTEM` until the session is over. The guard, not the window, does the locking:

| Bypass attempt | What happens |
|---|---|
| Closing or killing Lockdown | Nothing. Apps stay locked. |
| Killing the guard from Task Manager | A normal user can't see or end it. If an admin ends it, Windows starts it again within a minute, and the time it was down is added back. |
| Restarting the PC | The guard starts again at boot and carries on. |
| Changing the system clock | No effect. Time is counted with the uptime clock, so it only counts down while the PC is on. |
| Editing Lockdown's settings | No effect. The session's state lives in `C:\ProgramData\Lockdown`, which only admins can change. |
| Copying and renaming a locked `.exe` | Still closed. The guard matches the program's built-in original file name. |
| Deleting the browser's website rules | The guard puts them back. |
| Other browsers (Opera, Vivaldi, ...) | Closed while websites are blocked, because they ignore the rules. |

When the time is up, the guard removes the website rules, deletes its state and unregisters itself.

If you decline the admin prompt you can still run a **basic session**: applications are locked by the Lockdown window itself (closing it ends the session) and websites aren't blocked.

**Honest limit:** on a PC where you're an administrator, nothing is truly unbreakable. Someone determined can still delete the scheduled task from an elevated prompt. Strict mode makes that a deliberate effort instead of one click.

## What it changes on your PC

| Where | What | When |
|---|---|---|
| `%APPDATA%\Lockdown\config.json` | Your settings | Always |
| `C:\ProgramData\Lockdown\state.json` | Session state for the guard | During a strict session |
| Task Scheduler: `Lockdown Guard` | The guard (runs as SYSTEM) | During a strict session |
| `HKLM\SOFTWARE\Policies\Google\Chrome`, `...\Microsoft\Edge`, `...\BraveSoftware\Brave` (`URLBlocklist`, `URLAllowlist`) and `HKLM\SOFTWARE\Policies\Mozilla\Firefox\WebsiteFilter` | Website rules | During a session with website blocking |
| Startup folder: `Lockdown.lnk` | Reopens the window after a reboot | During a session |

Firefox only reads website rules when it starts, so Lockdown restarts it at the start and offers to at the end (your tabs come back).

## Files

| File | What it is |
|---|---|
| `Lockdown.ps1` | The app |
| `Lockdown.bat` | First-run helper: builds `Lockdown.exe` if needed and starts it |
| `Launcher.cs` | Source of `Lockdown.exe`, which starts the app with no console window |
| `Build-Launcher.ps1` | Builds `Lockdown.exe` from `Launcher.cs` |
| `Lockdown.ico` | The app icon |

## Removing everything manually

Normally nothing needs cleaning up. If a session was interrupted in a way that left something behind, Lockdown offers to clean up the next time you open it. To do it by hand, run this in an **administrator** PowerShell:

```powershell
Unregister-ScheduledTask -TaskName 'Lockdown Guard' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Lockdown" -Recurse -Force -ErrorAction SilentlyContinue
foreach ($k in 'Google\Chrome', 'Microsoft\Edge', 'BraveSoftware\Brave') {
    Remove-Item "HKLM:\SOFTWARE\Policies\$k\URLBlocklist", "HKLM:\SOFTWARE\Policies\$k\URLAllowlist" -Recurse -Force -ErrorAction SilentlyContinue
}
Remove-Item 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\WebsiteFilter' -Recurse -Force -ErrorAction SilentlyContinue
```

Then delete `%APPDATA%\Lockdown` if you also want your settings gone.

## Credits

Icons from [Tabler Icons](https://tabler.io/icons), Copyright (c) 2020-2024 Paweł Kuna, used under the MIT licence.
