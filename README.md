# Lockdown

An app that blocks websites and applications from being accessed for a set duration to force you to lock-in. A compact, always-on-top window for Windows: pick a length, choose what to lock, press Start. Once a session starts, it can't be stopped early.

| Ready | Websites | Starting | Locked |
|:---:|:---:|:---:|:---:|
| <img src="docs/idle.png" width="200" alt="Lockdown ready to start a 45-minute session"> | <img src="docs/websites.png" width="200" alt="Websites tab in Allow Only mode"> | <img src="docs/start.png" width="200" alt="Confirmation before a session starts"> | <img src="docs/locked.png" width="200" alt="A session in progress with the countdown ring"> |

## Features

- **Lock applications:** pick from your installed apps or any `.exe`. Locked apps close the moment they open.
- **Lock websites:** either **Allow Only** (block everything except your list) or **Block List** (block only your list). Type a name like `youtube` and every domain that site uses is covered.
- **Strict mode:** sessions can't be ended early, and the usual workarounds don't work (see below).
- **Your own session lengths** (`25`, `45`, `1h30` ...), a smooth countdown ring, a size setting per monitor, and a tray icon while a session runs.

## Getting started

Requires Windows 10 or 11. Strict mode and website blocking need an administrator account (one Windows prompt per session).

1. Download or clone this repository.
2. Double-click **`Lockdown.bat`** once. It builds `Lockdown.exe` from [`Launcher.cs`](Launcher.cs) with the C# compiler built into Windows, then starts the app.
3. After that, open **`Lockdown.exe`**. To pin it, right-click its taskbar button while it's running.

No prebuilt binary is included: `Lockdown.exe` is a small launcher compiled on your PC so the app starts without a console window. You can also run `Lockdown.ps1` directly with PowerShell.

## Strict mode

When a session starts, Lockdown sets up a hidden scheduled task, **Lockdown Guard**, that runs as `SYSTEM` and does the locking until time is up. Then it removes itself.

| If you try to... | What happens |
|---|---|
| Close or kill Lockdown | Nothing. Apps stay locked. |
| End the guard in Task Manager | A normal user can't. If an admin does, Windows restarts it within a minute and adds the lost time back. |
| Restart the PC or change the clock | The guard resumes at boot and counts uptime, not clock time. |
| Edit Lockdown's settings | Ignored. Session state lives in an admin-only folder. |
| Rename a locked `.exe` | Still closed (matched by its built-in original name). |
| Delete the browser rules | The guard puts them back. |

If you decline the admin prompt, you get a **basic session** instead: apps are locked by the window itself and websites aren't blocked.

As an administrator you can still remove the guard on purpose. Strict mode makes quitting a deliberate effort, not a single click.

## Browsers

- **Chrome, Edge, Brave, Chromium and Firefox** follow your website rules. Firefox is restarted at the start of a session so the rules apply, and your tabs come back.
- **Opera, Opera GX, Vivaldi, Arc, Zen, LibreWolf, Waterfox, Floorp, Pale Moon, Basilisk, SeaMonkey, DuckDuckGo, Thorium, Yandex, Maxthon, Slimjet, Iridium, CatsXP and Internet Explorer** ignore website rules, so they're closed for the whole session.
- Browsers built into other apps, renamed portable browsers and Tor Browser aren't covered. Add them under **Applications** to close them.

## Cleanup

Lockdown removes everything it sets up when a session ends, and offers to clean up next time you open it if a session was interrupted.

<details>
<summary>What it changes, and how to remove it by hand</summary>

| Where | What |
|---|---|
| `%APPDATA%\Lockdown` | Your settings |
| `C:\ProgramData\Lockdown` and the scheduled task `Lockdown Guard` | The guard, during a strict session |
| `HKLM\SOFTWARE\Policies\` for Chrome, Edge, Brave, Chromium (`URLBlocklist`, `URLAllowlist`) and Firefox (`WebsiteFilter`) | Website rules, during a session |
| `Lockdown.lnk` in the Startup folder | Reopens the window after a reboot, during a session |

Run in an **administrator** PowerShell:

```powershell
Unregister-ScheduledTask -TaskName 'Lockdown Guard' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Lockdown" -Recurse -Force -ErrorAction SilentlyContinue
foreach ($k in 'Google\Chrome', 'Microsoft\Edge', 'BraveSoftware\Brave', 'Chromium') {
    Remove-Item "HKLM:\SOFTWARE\Policies\$k\URLBlocklist", "HKLM:\SOFTWARE\Policies\$k\URLAllowlist" -Recurse -Force -ErrorAction SilentlyContinue
}
Remove-Item 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\WebsiteFilter' -Recurse -Force -ErrorAction SilentlyContinue
```

</details>

## Credits

Icons from [Tabler Icons](https://tabler.io/icons), Copyright (c) 2020-2024 Paweł Kuna, MIT licence.
