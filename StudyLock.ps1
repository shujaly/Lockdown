# Study Lock - closes distracting apps and blocks websites for the length of a study session.
param([switch]$Startup)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# ---------- paths & single instance ----------
$DataDir    = Join-Path $env:APPDATA 'StudyLock'
$ConfigPath = Join-Path $DataDir 'config.json'
$StartupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Study Lock.lnk'
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

$mutex = New-Object System.Threading.Mutex($false, 'Local\StudyLockSingleInstance')
$owned = $false
try { $owned = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
$showSignal = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Local\StudyLockShowWindow')
if (-not $owned) {
    # Already running: ask that copy to show its window, then quit.
    if (-not $Startup) { [void]$showSignal.Set() }
    return
}

# ---------- icons (Tabler outline set, MIT licence) ----------
$IconPaths = @{
    'lock' = 'M5 13a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v6a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-6z M11 16a1 1 0 1 0 2 0a1 1 0 0 0 -2 0 M8 11v-4a4 4 0 1 1 8 0v4'
    'minus' = 'M5 12l14 0'
    'x' = 'M18 6l-12 12 M6 6l12 12'
    'plus' = 'M12 5l0 14 M5 12l14 0'
    'check' = 'M5 12l5 5l10 -10'
    'alert-triangle' = 'M12 9v4 M10.363 3.591l-8.106 13.534a1.914 1.914 0 0 0 1.636 2.871h16.214a1.914 1.914 0 0 0 1.636 -2.87l-8.106 -13.536a1.914 1.914 0 0 0 -3.274 0z M12 16h.01'
    'arrow-left' = 'M5 12l14 0 M5 12l6 6 M5 12l6 -6'
    'search' = 'M10 10m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0 M21 21l-6 -6'
    'world' = 'M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0 M3.6 9h16.8 M3.6 15h16.8 M11.5 3a17 17 0 0 0 0 18 M12.5 3a17 17 0 0 1 0 18'
    'app-window' = 'M3 5m0 2a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v10a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2z M6 8h.01 M9 8h.01'
    'device-gamepad-2' = 'M12 5h3.5a5 5 0 0 1 0 10h-5.5l-4.015 4.227a2.3 2.3 0 0 1 -3.923 -2.035l1.634 -8.173a5 5 0 0 1 4.904 -4.019h3.4z M14 15l4.07 4.284a2.3 2.3 0 0 0 3.925 -2.023l-1.6 -8.232 M8 9v2 M7 10h2 M14 10h2'
    'school' = 'M22 9l-10 -4l-10 4l10 4l10 -4v6 M6 10.6v5.4a6 3 0 0 0 12 0v-5.4'
    'file-text' = 'M14 3v4a1 1 0 0 0 1 1h4 M17 21h-10a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2h7l5 5v11a2 2 0 0 1 -2 2z M9 9l1 0 M9 13l6 0 M9 17l6 0'
    'folder' = 'M5 4h4l3 3h7a2 2 0 0 1 2 2v8a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-11a2 2 0 0 1 2 -2'
    'clock' = 'M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0 M12 7v5l3 3'
    'zoom-in' = 'M10 10m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0 M7 10l6 0 M10 7l0 6 M21 21l-6 -6'
    'pin' = 'M15 4.5l-4 4l-4 1.5l-1.5 1.5l7 7l1.5 -1.5l1.5 -4l4 -4 M9 15l-4.5 4.5 M14.5 4l5.5 5.5'
    'pinned' = 'M9 4v6l-2 4v2h10v-2l-2 -4v-6 M12 16l0 5 M8 4l8 0'
    'grip-horizontal' = 'M5 9m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M5 15m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M12 9m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M12 15m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M19 9m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M19 15m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0'
    'brand-discord' = 'M8 12a1 1 0 1 0 2 0a1 1 0 0 0 -2 0 M14 12a1 1 0 1 0 2 0a1 1 0 0 0 -2 0 M15.5 17c0 1 1.5 3 2 3c1.5 0 2.833 -1.667 3.5 -3c.667 -1.667 .5 -5.833 -1.5 -11.5c-1.457 -1.015 -3 -1.34 -4.5 -1.5l-.972 1.923a11.913 11.913 0 0 0 -4.053 0l-.975 -1.923c-1.5 .16 -3.043 .485 -4.5 1.5c-2 5.667 -2.167 9.833 -1.5 11.5c.667 1.333 2 3 3.5 3c.5 0 2 -2 2 -3 M7 16.5c3.5 1 6.5 1 10 0'
    'brand-steam' = 'M16.5 5a4.5 4.5 0 1 1 -.653 8.953l-4.347 3.009l0 .038a3 3 0 0 1 -2.824 3l-.176 0a3 3 0 0 1 -2.94 -2.402l-2.56 -1.098v-3.5l3.51 1.755a2.989 2.989 0 0 1 2.834 -.635l2.727 -3.818a4.5 4.5 0 0 1 4.429 -5.302z M15.5 9.5 a1 1 0 1 0 2 0 a1 1 0 1 0 -2 0'
    'brand-spotify' = 'M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0 M8 11.973c2.5 -1.473 5.5 -.973 7.5 .527 M9 15c1.5 -1 4 -1 5 .5 M7 9c2 -1 6 -2 10 .5'
    'brand-chrome' = 'M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0 M12 12m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0 M12 9h8.4 M14.598 13.5l-4.2 7.275 M9.402 13.5l-4.2 -7.275'
    'brand-firefox' = 'M4.028 7.82a9 9 0 1 0 12.823 -3.4c-1.636 -1.02 -3.064 -1.02 -4.851 -1.02h-1.647 M4.914 9.485c-1.756 -1.569 -.805 -5.38 .109 -6.17c.086 .896 .585 1.208 1.111 1.685c.88 -.275 1.313 -.282 1.867 0c.82 -.91 1.694 -2.354 2.628 -2.093c-1.082 1.741 -.07 3.733 1.371 4.173c-.17 .975 -1.484 1.913 -2.76 2.686c-1.296 .938 -.722 1.85 0 2.234c.949 .506 3.611 -1 4.545 .354c-1.698 .102 -1.536 3.107 -3.983 2.727c2.523 .957 4.345 .462 5.458 -.34c1.965 -1.52 2.879 -3.542 2.879 -5.557c-.014 -1.398 .194 -2.695 -1.26 -4.75'
    'brand-edge' = 'M20.978 11.372a9 9 0 1 0 -1.593 5.773 M20.978 11.372c.21 2.993 -5.034 2.413 -6.913 1.486c1.392 -1.6 .402 -4.038 -2.274 -3.851c-1.745 .122 -2.927 1.157 -2.784 3.202c.28 3.99 4.444 6.205 10.36 4.79 M3.022 12.628c-.283 -4.043 8.717 -7.228 11.248 -2.688 M12.628 20.978c-2.993 .21 -5.162 -4.725 -3.567 -9.748'
    'brand-opera' = 'M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0 M12 12m-3 0a3 5 0 1 0 6 0a3 5 0 1 0 -6 0'
    'brand-whatsapp' = 'M3 21l1.65 -3.8a9 9 0 1 1 3.4 2.9l-5.05 .9 M9 10a.5 .5 0 0 0 1 0v-1a.5 .5 0 0 0 -1 0v1a5 5 0 0 0 5 5h1a.5 .5 0 0 0 0 -1h-1a.5 .5 0 0 0 0 1'
    'brand-telegram' = 'M15 10l-4 4l6 6l4 -16l-18 7l4 2l2 6l3 -4'
    'brand-tiktok' = 'M21 7.917v4.034a9.948 9.948 0 0 1 -5 -1.951v4.5a6.5 6.5 0 1 1 -8 -6.326v4.326a2.5 2.5 0 1 0 4 2v-11.5h4.083a6.005 6.005 0 0 0 4.917 4.917z'
    'brand-vscode' = 'M16 3v18l4 -2.5v-13z M9.165 13.903l-4.165 3.597l-2 -1l4.333 -4.5m1.735 -1.802l6.932 -7.198v5l-4.795 4.141 M16 16.5l-11 -10l-2 1l13 13.5'
    'brand-youtube' = 'M2 8a4 4 0 0 1 4 -4h12a4 4 0 0 1 4 4v8a4 4 0 0 1 -4 4h-12a4 4 0 0 1 -4 -4v-8z M10 9l5 3l-5 3z'
    'brand-google-drive' = 'M12 10l-6 10l-3 -5l6 -10z M9 15h12l-3 5h-12 M15 15l-6 -10h6l6 10z'
    'brand-gmail' = 'M16 20h3a1 1 0 0 0 1 -1v-14a1 1 0 0 0 -1 -1h-3v16z M5 20h3v-16h-3a1 1 0 0 0 -1 1v14a1 1 0 0 0 1 1z M16 4l-4 4l-4 -4 M4 6.5l8 7.5l8 -7.5'
    'brand-instagram' = 'M4 4m0 4a4 4 0 0 1 4 -4h8a4 4 0 0 1 4 4v8a4 4 0 0 1 -4 4h-8a4 4 0 0 1 -4 -4z M12 12m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0 M16.5 7.5l0 .01'
    'brand-facebook' = 'M7 10v4h3v7h4v-7h3l1 -4h-4v-2a1 1 0 0 1 1 -1h3v-4h-3a5 5 0 0 0 -5 5v2h-3'
    'brand-x' = 'M4 4l11.733 16h4.267l-11.733 -16z M4 20l6.768 -6.768m2.46 -2.46l6.772 -6.772'
    'brand-reddit' = 'M12 8c2.648 0 5.028 .826 6.675 2.14a2.5 2.5 0 0 1 2.326 4.36c0 3.59 -4.03 6.5 -9 6.5c-4.875 0 -8.845 -2.8 -9 -6.294l-1 -.206a2.5 2.5 0 0 1 2.326 -4.36c1.646 -1.313 4.026 -2.14 6.674 -2.14z M12 8l1 -5l6 1 M19 4m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M10 17c.667 .333 1.333 .5 2 .5s1.333 -.167 2 -.5 M8.5 13 a0.5 0.5 0 1 0 1 0 a0.5 0.5 0 1 0 -1 0 M14.5 13 a0.5 0.5 0 1 0 1 0 a0.5 0.5 0 1 0 -1 0'
    'brand-netflix' = 'M9 3l10 18h-4l-10 -18z M5 3v18h4v-10.5 M19 21v-18h-4v10.5'
    'brand-twitch' = 'M4 5v11a1 1 0 0 0 1 1h2v4l4 -4h5.584c.266 0 .52 -.105 .707 -.293l2.415 -2.414c.187 -.188 .293 -.442 .293 -.708v-8.585a1 1 0 0 0 -1 -1h-14a1 1 0 0 0 -1 1z M16 8l0 4 M12 8l0 4'
    'brand-snapchat' = 'M16.882 7.842a4.882 4.882 0 0 0 -9.764 0c0 4.273 -.213 6.409 -4.118 8.118c2 .882 2 .882 3 3c3 0 4 2 6 2s3 -2 6 -2c1 -2.118 1 -2.118 3 -3c-3.906 -1.709 -4.118 -3.845 -4.118 -8.118zm-13.882 8.119c4 -2.118 4 -4.118 1 -7.118m17 7.118c-4 -2.118 -4 -4.118 -1 -7.118'
    'brand-pinterest' = 'M8 20l4 -9 M10.7 14c.437 1.263 1.43 2 2.55 2c2.071 0 3.75 -1.554 3.75 -4a5 5 0 1 0 -9.7 1.7 M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0'
    'brand-openai' = 'M11.217 19.384a3.501 3.501 0 0 0 6.783 -1.217v-5.167l-6 -3.35 M5.214 15.014a3.501 3.501 0 0 0 4.446 5.266l4.34 -2.534v-6.946 M6 7.63c-1.391 -.236 -2.787 .395 -3.534 1.689a3.474 3.474 0 0 0 1.271 4.745l4.263 2.514l6 -3.348 M12.783 4.616a3.501 3.501 0 0 0 -6.783 1.217v5.067l6 3.45 M18.786 8.986a3.501 3.501 0 0 0 -4.446 -5.266l-4.34 2.534v6.946 M18 16.302c1.391 .236 2.787 -.395 3.534 -1.689a3.474 3.474 0 0 0 -1.271 -4.745l-4.308 -2.514l-5.955 3.42'
    'brand-minecraft' = 'M21 16.008v-8.018a1.98 1.98 0 0 0 -1 -1.717l-7 -4.008a2.016 2.016 0 0 0 -2 0l-7 4.008c-.619 .355 -1 1.01 -1 1.718v8.018c0 .709 .381 1.363 1 1.717l7 4.008c.62 .354 1.38 .354 2 0l7 -4.008c.619 -.355 1 -1.01 1 -1.718z M12 22v-10 M12 12l8.73 -5.04 M3.27 6.96l8.73 5.04 M12 17l3.003 -1.668m3 -1.667l2.997 -1.665m-9 5l-9 -5 M15 17l3 -1.67v-3l-3 1.67z'
    'brand-valorant' = 'M14.5 14h4.5l2 -2v-6z M9 19h5l-11 -13v6z'
}
$Geo = @{}
foreach ($k in $IconPaths.Keys) { $g = [System.Windows.Media.Geometry]::Parse($IconPaths[$k]); $g.Freeze(); $Geo[$k] = $g }
$AppGlyphs = @{
    'discord' = 'brand-discord'; 'discordcanary' = 'brand-discord'; 'discordptb' = 'brand-discord'
    'steam' = 'brand-steam'; 'spotify' = 'brand-spotify'; 'chrome' = 'brand-chrome'; 'firefox' = 'brand-firefox'
    'private_browsing' = 'brand-firefox'; 'msedge' = 'brand-edge'; 'opera' = 'brand-opera'; 'whatsapp' = 'brand-whatsapp'
    'telegram' = 'brand-telegram'; 'tiktok' = 'brand-tiktok'; 'code' = 'brand-vscode'; 'robloxplayerbeta' = 'device-gamepad-2'
    'robloxplayerlauncher' = 'device-gamepad-2'; 'minecraft' = 'brand-minecraft'; 'minecraftlauncher' = 'brand-minecraft'
    'valorant' = 'brand-valorant'; 'riotclientservices' = 'brand-valorant'
}

# ---------- apps ----------
# Apps that can never be locked (Windows itself, or the thing running Study Lock).
$Protected = @('explorer','powershell','pwsh','powershell_ise','conhost','system','idle','registry','smss','csrss',
    'wininit','winlogon','services','lsass','svchost','dwm','fontdrvhost','sihost','ctfmon','runtimebroker',
    'searchhost','startmenuexperiencehost','shellexperiencehost','textinputhost','applicationframehost',
    'securityhealthsystray','securityhealthservice','msmpeng','lockapp','logonui','userinit','claude')
# Apps that run under more than one process name.
$AppAliases = @{
    'robloxplayerbeta'     = @('robloxplayerbeta', 'robloxplayerlauncher')
    'robloxplayerlauncher' = @('robloxplayerbeta', 'robloxplayerlauncher')
}
# Browsers that ignore website rules get closed outright while websites are blocked.
$UnmanagedBrowsers = @('opera', 'vivaldi', 'librewolf', 'waterfox', 'floorp', 'zen', 'arc', 'iexplore')

# ---------- websites ----------
# Type a name like "youtube" and every domain that site uses is covered. Anything else becomes name.com.
$SiteDomains = [ordered]@{
    'youtube'   = @('youtube.com', 'youtu.be', 'youtube-nocookie.com', 'youtubekids.com', 'ytimg.com', 'googlevideo.com')
    'whatsapp'  = @('whatsapp.com', 'whatsapp.net', 'wa.me')
    'drive'     = @('drive.google.com', 'drive.usercontent.google.com', 'docs.google.com', 'lh3.google.com')
    'classroom' = @('classroom.google.com', 'docs.google.com', 'drive.google.com', 'drive.usercontent.google.com', 'lh3.google.com')
    'docs'      = @('docs.google.com')
    'gmail'     = @('mail.google.com')
    'tiktok'    = @('tiktok.com', 'tiktokcdn.com', 'tiktokv.com')
    'instagram' = @('instagram.com', 'cdninstagram.com')
    'facebook'  = @('facebook.com', 'fb.com', 'fbcdn.net', 'messenger.com')
    'twitter'   = @('twitter.com', 'x.com', 'twimg.com')
    'reddit'    = @('reddit.com', 'redd.it', 'redditmedia.com', 'redditstatic.com')
    'netflix'   = @('netflix.com', 'nflxvideo.net')
    'twitch'    = @('twitch.tv', 'twitchcdn.net')
    'roblox'    = @('roblox.com', 'rbxcdn.com')
    'discord'   = @('discord.com', 'discord.gg', 'discordapp.com', 'discordapp.net')
    'snapchat'  = @('snapchat.com')
    'pinterest' = @('pinterest.com', 'pinimg.com')
    'spotify'   = @('spotify.com', 'scdn.co')
    'steam'     = @('steampowered.com', 'steamcommunity.com')
    'chatgpt'   = @('chatgpt.com', 'openai.com')
}
$SiteNames = @{
    'youtube' = 'YouTube'; 'whatsapp' = 'WhatsApp'; 'drive' = 'Google Drive'; 'classroom' = 'Google Classroom'; 'docs' = 'Google Docs'
    'gmail' = 'Gmail'; 'tiktok' = 'TikTok'; 'instagram' = 'Instagram'; 'facebook' = 'Facebook'; 'twitter' = 'X (Twitter)'
    'reddit' = 'Reddit'; 'netflix' = 'Netflix'; 'twitch' = 'Twitch'; 'roblox' = 'Roblox'; 'discord' = 'Discord'
    'snapchat' = 'Snapchat'; 'pinterest' = 'Pinterest'; 'spotify' = 'Spotify'; 'steam' = 'Steam'; 'chatgpt' = 'ChatGPT'
}
$SiteGlyphs = @{
    'youtube' = 'brand-youtube'; 'whatsapp' = 'brand-whatsapp'; 'drive' = 'brand-google-drive'; 'classroom' = 'school'
    'docs' = 'file-text'; 'gmail' = 'brand-gmail'; 'tiktok' = 'brand-tiktok'; 'instagram' = 'brand-instagram'
    'facebook' = 'brand-facebook'; 'twitter' = 'brand-x'; 'reddit' = 'brand-reddit'; 'netflix' = 'brand-netflix'
    'twitch' = 'brand-twitch'; 'roblox' = 'device-gamepad-2'; 'discord' = 'brand-discord'; 'snapchat' = 'brand-snapchat'
    'pinterest' = 'brand-pinterest'; 'spotify' = 'brand-spotify'; 'steam' = 'brand-steam'; 'chatgpt' = 'brand-openai'
}
$SiteNicknames = @{
    'google drive' = 'drive'; 'google classroom' = 'classroom'; 'google docs' = 'docs'; 'yt' = 'youtube'
    'x' = 'twitter'; 'insta' = 'instagram'; 'ig' = 'instagram'; 'fb' = 'facebook'; 'snap' = 'snapchat'
}
# Google sign-in and page resources, allowed automatically whenever a Google site is allowed.
$GoogleSupport = @('accounts.google.com', 'www.google.com/accounts', 'www.google.com/recaptcha', 'accounts.youtube.com',
    'gstatic.com', 'googleusercontent.com', 'googleapis.com', 'apis.google.com', 'ogs.google.com', 'clients6.google.com')
$FirefoxExe  = Join-Path $env:ProgramFiles 'Mozilla Firefox\firefox.exe'
$GuardTaskName = 'StudyLock Guard'
$GuardDir      = Join-Path $env:ProgramData 'StudyLock'      # admin-only folder; the guard's session state lives here
$GuardState    = Join-Path $GuardDir 'state.json'

# ---------- strict mode ----------
# A session is enforced by a hidden SYSTEM scheduled task (the guard), not by this window:
#  - closing or killing Study Lock changes nothing, and a killed guard is restarted by Windows within a minute
#  - it starts again at boot, and counts time with the uptime clock, so reboots and clock changes don't end a session
#  - its state sits in an admin-only folder, so editing Study Lock's own settings can't end a session either
#  - it also closes renamed copies of locked programs, and puts website rules back if they're deleted
# Shared website-rule functions, used by both the guard and the one-time elevated starter.
$WebRulesCode = @'
$ChromeKeys   = @('HKLM:\SOFTWARE\Policies\Google\Chrome', 'HKLM:\SOFTWARE\Policies\Microsoft\Edge', 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave')
$FirefoxKey   = 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox'
$BlockChrome  = @(__BLOCK_CHROME__)
$AllowChrome  = @(__ALLOW_CHROME__)
$BlockFirefox = @(__BLOCK_FIREFOX__)
$AllowFirefox = @(__ALLOW_FIREFOX__)
function Write-List($key, $values) {
    New-Item $key -Force | Out-Null
    $i = 1; foreach ($v in $values) { New-ItemProperty $key -Name "$i" -Value $v -PropertyType String -Force | Out-Null; $i++ }
}
function Clear-WebRules {
    foreach ($k in $ChromeKeys) { foreach ($s in 'URLBlocklist', 'URLAllowlist') { Remove-Item "$k\$s" -Recurse -Force -ErrorAction SilentlyContinue } }
    Remove-Item "$FirefoxKey\WebsiteFilter" -Recurse -Force -ErrorAction SilentlyContinue
}
function Set-WebRules {
    Clear-WebRules
    foreach ($k in $ChromeKeys) {
        Write-List "$k\URLBlocklist" $BlockChrome
        if ($AllowChrome.Count -gt 0) { Write-List "$k\URLAllowlist" $AllowChrome }
    }
    Write-List "$FirefoxKey\WebsiteFilter\Block" $BlockFirefox
    if ($AllowFirefox.Count -gt 0) { Write-List "$FirefoxKey\WebsiteFilter\Exceptions" $AllowFirefox }
}
function Test-WebRules { (Test-Path "$($ChromeKeys[0])\URLBlocklist") -and (Test-Path "$FirefoxKey\WebsiteFilter\Block") }
'@

# The guard itself (runs as SYSTEM until the session's time is used up).
$GuardTemplate = @'
$ErrorActionPreference = 'SilentlyContinue'
$Names     = @(__NAMES__)
$WebOn     = $__WEBON__
$StateFile = '__STATE__'
$TaskName  = '__TASK__'
__WEBRULES__
function Save-State($left) {
    $o = [ordered]@{ remaining = [int][Math]::Ceiling($left); total = $script:Total; heartbeat = [DateTime]::UtcNow.Ticks
                     blocked = $script:Count; lastBlocked = $script:Last; webOn = $WebOn; names = $Names }
    $o | ConvertTo-Json -Compress | Set-Content $StateFile -Encoding UTF8
}
$s = Get-Content $StateFile -Raw | ConvertFrom-Json
if (-not $s) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false; exit 0 }   # no session: nothing to guard
$script:Total = [int]$s.total; $script:Count = [int]$s.blocked; $script:Last = [string]$s.lastBlocked
$base = [double]$s.remaining
$sw = [Diagnostics.Stopwatch]::StartNew()            # uptime-based: clock changes don't affect it
$nextSave = 0.0; $nextScan = 0.0; $lastHit = -100.0
$origCache = @{}   # exe path -> its built-in original name
while ($true) {
    $now = $sw.Elapsed.TotalSeconds
    $left = $base - $now
    if ($left -le 0) { break }
    $hit = @()
    if ($Names.Count -gt 0) {
        foreach ($p in @(Get-Process -Name $Names)) { $hit += $p.ProcessName.ToLower(); Stop-Process -Id $p.Id -Force }
        if ($now -ge $nextScan) {
            # renamed copies: match on the program's built-in original file name
            $nextScan = $now + 3
            foreach ($p in Get-Process) {
                $path = $p.Path
                if (-not $path) { continue }
                if (-not $origCache.ContainsKey($path)) {
                    $o = ''; try { $o = [Diagnostics.FileVersionInfo]::GetVersionInfo($path).OriginalFilename } catch {}
                    $origCache[$path] = $(if ($o) { [IO.Path]::GetFileNameWithoutExtension($o).ToLower() } else { '' })
                }
                $n = $origCache[$path]
                if ($n -and $Names -contains $n -and $p.ProcessName.ToLower() -ne $n) { $hit += $n; Stop-Process -Id $p.Id -Force }
            }
        }
    }
    if ($WebOn -and -not (Test-WebRules)) { Set-WebRules }
    if ($hit.Count -gt 0) {
        if ($now - $lastHit -gt 3) { $script:Count++ }    # one launch often spawns several processes
        $lastHit = $now
        $script:Last = (@($hit | Select-Object -Unique) -join ',')
        $nextSave = 0
    }
    if ($now -ge $nextSave) { Save-State $left; $nextSave = $now + 5 }
    Start-Sleep -Milliseconds 700
}
Clear-WebRules
Remove-Item $StateFile -Force
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
'@

# Runs once, elevated (the UAC prompt). "Start" sets up the guard; "Clear" removes everything (only offered when no session is running).
$StarterTemplate = @'
param([string]$Mode)
$ErrorActionPreference = 'Stop'
$Dir       = '__DIR__'
$StateFile = '__STATE__'
$TaskName  = '__TASK__'
$WebOn     = $__WEBON__
__WEBRULES__
function Stop-All {
    foreach ($t in $TaskName, 'StudyLock Unblock Websites') {
        Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
    }
    Clear-WebRules
    Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
}
try {
    if ($Mode -eq 'Clear') { Stop-All; exit 0 }
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    # SYSTEM and Administrators can change it, everyone else can only read it
    & icacls.exe $Dir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
    Stop-All
    if ($WebOn) { Set-WebRules }
    [ordered]@{ remaining = __SECONDS__; total = __SECONDS__; heartbeat = [DateTime]::UtcNow.Ticks; blocked = 0; lastBlocked = ''; webOn = $WebOn } |
        ConvertTo-Json -Compress | Set-Content $StateFile -Encoding UTF8
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand __GUARD_B64__'
    $atBoot    = New-ScheduledTaskTrigger -AtStartup
    $everyMin  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(-5) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 30)
    $settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -Hidden
    $principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $atBoot, $everyMin -Settings $settings -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName
    exit 0
} catch {
    "$(Get-Date -Format s) $($_.Exception.Message)" | Add-Content (Join-Path $env:TEMP 'StudyLock-starter.log')
    try { Stop-All } catch {}
    exit 1
}
'@

# ---------- state ----------
$script:Apps         = New-Object System.Collections.ArrayList   # each: Label, Names[], Path
$script:AllowSites   = New-Object System.Collections.ArrayList
$script:BlockSites   = New-Object System.Collections.ArrayList
$script:Durations    = New-Object System.Collections.ArrayList   # minutes the user has added
$script:WebMode      = 'allow'    # off | allow | block
$script:Minutes      = 25
$script:SessionEnd   = $null      # UTC DateTime while a session is running
$script:SessionTotal = 25         # minutes, for the ring
$script:BlockedCount = 0
$script:WebBlock     = $false     # websites are blocked for the current session
$script:OfferFirefox = $false
$script:Pinned       = $true      # miniplayer stays on top of other windows
$script:Scales       = @{}        # screen resolution -> 'auto' or a size like '1.25'
$script:Strict       = $false     # session is enforced by the SYSTEM guard
$script:GuardMisses  = 0
$script:LastBlock    = [DateTime]::MinValue
$script:Exiting      = $false
$script:Loading      = $true
$script:IconCache    = @{}
$script:PickAll      = @()
$script:DlgPrimary   = $null
$script:DlgSecondary = $null

# ---------- WPF resources ----------
$app = New-Object System.Windows.Application
$app.ShutdownMode = 'OnExplicitShutdown'

$iconResources = ($IconPaths.Keys | ForEach-Object { "  <Geometry x:Key=`"i-$_`">$($IconPaths[$_])</Geometry>" }) -join "`r`n"
$app.Resources = [System.Windows.Markup.XamlReader]::Parse((@'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
__ICONS__
  <Style x:Key="Ico" TargetType="ContentControl">
    <Setter Property="Width" Value="16"/>
    <Setter Property="Height" Value="16"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="IsTabStop" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ContentControl">
          <Viewbox>
            <Canvas Width="24" Height="24">
              <Path Data="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}" Stroke="{TemplateBinding Foreground}"
                    StrokeThickness="2" StrokeLineJoin="Round" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
            </Canvas>
          </Viewbox>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="Btn" TargetType="Button">
    <Setter Property="Foreground" Value="#F1EFE8"/>
    <Setter Property="Background" Value="#444441"/>
    <Setter Property="Padding" Value="12,5"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.88"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.75"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.45"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource Btn}">
    <Setter Property="Background" Value="#378ADD"/>
    <Setter Property="Foreground" Value="#FFFFFF"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
  </Style>
  <Style x:Key="IconBtn" TargetType="Button">
    <Setter Property="Foreground" Value="#B4B2A9"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Padding" Value="6"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter Property="Foreground" Value="#F1EFE8"/>
              <Setter TargetName="b" Property="Background" Value="#3A3A37"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="RowBtn" TargetType="Button">
    <Setter Property="Foreground" Value="#B4B2A9"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="HorizontalContentAlignment" Value="Left"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="6,4">
            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter Property="Foreground" Value="#F1EFE8"/>
              <Setter TargetName="b" Property="Background" Value="#353533"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="Chip" TargetType="Button">
    <Setter Property="Foreground" Value="#D3D1C7"/>
    <Setter Property="BorderBrush" Value="#5F5E5A"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Margin" Value="2,0"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6" Padding="7,1" MinHeight="22">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#353533"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="Tab" TargetType="RadioButton">
    <Setter Property="Foreground" Value="#B4B2A9"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Border x:Name="b" BorderThickness="0,0,0,2" BorderBrush="Transparent" Padding="0,0,0,4" Margin="0,0,12,-1" Background="Transparent">
            <ContentPresenter/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="b" Property="BorderBrush" Value="#378ADD"/>
              <Setter Property="Foreground" Value="#F1EFE8"/>
            </Trigger>
            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#F1EFE8"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="Seg" TargetType="RadioButton">
    <Setter Property="Foreground" Value="#B4B2A9"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Border x:Name="b" Background="Transparent" CornerRadius="5" Padding="4,3">
            <ContentPresenter HorizontalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="b" Property="Background" Value="#5F5E5A"/>
              <Setter Property="Foreground" Value="#F1EFE8"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.6"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="TextBox">
    <Setter Property="Foreground" Value="#F1EFE8"/>
    <Setter Property="Background" Value="#383836"/>
    <Setter Property="CaretBrush" Value="#F1EFE8"/>
    <Setter Property="SelectionBrush" Value="#378ADD"/>
    <Setter Property="Padding" Value="7,4"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="TextBox">
          <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="Transparent" BorderThickness="1" CornerRadius="6">
            <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#378ADD"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="SbPage" TargetType="RepeatButton">
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="IsTabStop" Value="False"/>
    <Setter Property="Template">
      <Setter.Value><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="SbThumb" TargetType="Thumb">
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Thumb">
          <Border x:Name="t" Background="#5F5E5A" CornerRadius="3"/>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="t" Property="Background" Value="#888780"/></Trigger>
            <Trigger Property="IsDragging" Value="True"><Setter TargetName="t" Property="Background" Value="#B4B2A9"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="ScrollBar">
    <Setter Property="Width" Value="5"/>
    <Setter Property="MinWidth" Value="5"/>
    <Setter Property="Margin" Value="4,2,0,2"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ScrollBar">
          <Border Background="#333331" CornerRadius="3">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.DecreaseRepeatButton><RepeatButton Style="{StaticResource SbPage}" Command="ScrollBar.PageUpCommand"/></Track.DecreaseRepeatButton>
              <Track.IncreaseRepeatButton><RepeatButton Style="{StaticResource SbPage}" Command="ScrollBar.PageDownCommand"/></Track.IncreaseRepeatButton>
              <Track.Thumb><Thumb Style="{StaticResource SbThumb}"/></Track.Thumb>
            </Track>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="ListBox">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Foreground" Value="#F1EFE8"/>
    <Setter Property="Padding" Value="0"/>
    <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
  </Style>
  <Style x:Key="RowItem" TargetType="ListBoxItem">
    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ListBoxItem">
          <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="6,0">
            <ContentPresenter/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#353533"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="PickItem" TargetType="ListBoxItem">
    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    <!-- must stay focusable: WPF only selects a clicked row if it can take focus -->
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ListBoxItem">
          <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="6,3" Margin="0,1">
            <ContentPresenter/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#353533"/></Trigger>
            <Trigger Property="IsSelected" Value="True"><Setter TargetName="b" Property="Background" Value="#24384D"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
</ResourceDictionary>
'@).Replace('__ICONS__', $iconResources))

# ---------- main window ----------
$window = [System.Windows.Markup.XamlReader]::Parse(@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Study Lock" Width="272" Height="392" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ResizeMode="CanMinimize" WindowStartupLocation="CenterScreen" Topmost="True"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="12" Foreground="#F1EFE8"
        TextOptions.TextFormattingMode="Display" UseLayoutRounding="True">
  <Border Background="#2C2C2A" CornerRadius="10" BorderBrush="#3F3F3C" BorderThickness="1">
    <Grid>
      <Grid Margin="12,2,12,12">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>

        <Grid x:Name="TitleBar" Background="Transparent" Height="32">
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-lock}" Foreground="#85B7EB" Width="15" Height="15" Margin="0,0,7,0"/>
            <TextBlock Text="Study Lock" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,-5,0">
            <Button x:Name="ScaleBtn" Style="{StaticResource IconBtn}" Padding="5" ToolTip="Size">
              <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-zoom-in}" Width="13" Height="13"/>
            </Button>
            <Popup x:Name="ScalePopup" PlacementTarget="{Binding ElementName=ScaleBtn}" Placement="Bottom" StaysOpen="False"
                   AllowsTransparency="True" PopupAnimation="Fade" VerticalOffset="4">
              <Border Background="#383836" BorderBrush="#4A4A47" BorderThickness="1" CornerRadius="8" Padding="4" MinWidth="150">
                <StackPanel>
                  <TextBlock x:Name="ScaleTitle" Text="Size On This Screen" FontSize="10.5" Foreground="#888780" Margin="6,3,6,4"/>
                  <ItemsControl x:Name="ScaleList" Focusable="False">
                    <ItemsControl.ItemTemplate>
                      <DataTemplate>
                        <Button Style="{StaticResource RowBtn}" Tag="{Binding Value}" HorizontalContentAlignment="Stretch">
                          <Grid Width="130">
                            <TextBlock Text="{Binding Label}" Foreground="#F1EFE8" FontSize="12"/>
                            <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-check}" Foreground="#85B7EB" Width="12" Height="12"
                                            HorizontalAlignment="Right" Visibility="{Binding Tick}"/>
                          </Grid>
                        </Button>
                      </DataTemplate>
                    </ItemsControl.ItemTemplate>
                  </ItemsControl>
                </StackPanel>
              </Border>
            </Popup>
            <Button x:Name="PinBtn" Style="{StaticResource IconBtn}" Padding="5">
              <ContentControl x:Name="PinIcon" Style="{StaticResource Ico}" Tag="{StaticResource i-pinned}" Width="13" Height="13"/>
            </Button>
            <Button x:Name="MinBtn" Style="{StaticResource IconBtn}" Padding="5" ToolTip="Minimize">
              <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-minus}" Width="13" Height="13"/>
            </Button>
            <Button x:Name="CloseBtn" Style="{StaticResource IconBtn}" Padding="5" ToolTip="Close">
              <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-x}" Width="13" Height="13"/>
            </Button>
          </StackPanel>
        </Grid>

        <Grid x:Name="MainView" Grid.Row="1">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <Grid Width="106" Height="106" HorizontalAlignment="Center" Margin="0,2,0,10">
            <Ellipse Stroke="#444441" StrokeThickness="6"/>
            <Ellipse x:Name="Arc" Stroke="#378ADD" StrokeThickness="6" StrokeDashCap="Round" RenderTransformOrigin="0.5,0.5">
              <Ellipse.RenderTransform><RotateTransform Angle="-90"/></Ellipse.RenderTransform>
            </Ellipse>
            <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
              <TextBlock x:Name="TimeText" Text="25:00" FontSize="20" FontWeight="SemiBold" HorizontalAlignment="Center"/>
              <TextBlock x:Name="SubText" Foreground="#B4B2A9" FontSize="11" HorizontalAlignment="Center" Visibility="Collapsed"/>
            </StackPanel>
          </Grid>

          <StackPanel x:Name="DurRow" Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,10">
            <ItemsControl x:Name="DurList" Focusable="False">
              <ItemsControl.ItemsPanel><ItemsPanelTemplate><StackPanel Orientation="Horizontal"/></ItemsPanelTemplate></ItemsControl.ItemsPanel>
              <ItemsControl.ItemTemplate>
                <DataTemplate>
                  <Button Style="{StaticResource Chip}" Tag="{Binding SelTag}" BorderBrush="{Binding Border}" Foreground="{Binding Fg}"
                          Content="{Binding Label}" ToolTip="Click to Use, Right-Click to Remove"/>
                </DataTemplate>
              </ItemsControl.ItemTemplate>
            </ItemsControl>
            <TextBlock x:Name="DurHint" Text="Add a Session Length" Foreground="#B4B2A9" FontSize="11" VerticalAlignment="Center" Margin="0,0,5,0" Visibility="Collapsed"/>
            <TextBox x:Name="DurInput" Width="58" Height="22" Padding="5,1" FontSize="11" Margin="3,0" Visibility="Collapsed" ToolTip="Minutes, Like 45 or 1h30"/>
            <Button x:Name="AddDurBtn" Style="{StaticResource Chip}" ToolTip="Add a Session Length">
              <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-plus}" Width="11" Height="11"/>
            </Button>
          </StackPanel>

          <Border Grid.Row="2" BorderBrush="#5F5E5A" BorderThickness="0,0,0,1" Margin="0,0,0,4">
            <StackPanel Orientation="Horizontal">
              <RadioButton x:Name="TabApps" GroupName="Tabs" Style="{StaticResource Tab}" Content="Applications" IsChecked="True"/>
              <RadioButton x:Name="TabWeb" GroupName="Tabs" Style="{StaticResource Tab}" Content="Websites"/>
            </StackPanel>
          </Border>

          <Grid Grid.Row="3">
            <DockPanel x:Name="AppsPanel">
              <Button x:Name="AddAppRow" DockPanel.Dock="Bottom" Style="{StaticResource RowBtn}" Margin="0,1,0,0">
                <StackPanel Orientation="Horizontal">
                  <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-plus}" Width="14" Height="14" Margin="0,0,9,0"/>
                  <TextBlock Text="Add Application"/>
                </StackPanel>
              </Button>
              <Grid>
                <TextBlock x:Name="AppsEmpty" Text="No Applications Yet" Foreground="#B4B2A9" Margin="6,5" Visibility="Collapsed"/>
                <ListBox x:Name="AppsList" ItemContainerStyle="{StaticResource RowItem}">
                  <ListBox.ItemTemplate>
                    <DataTemplate>
                      <Grid x:Name="row" Background="Transparent" Height="26">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <ContentControl Style="{StaticResource Ico}" Tag="{Binding Geo}" Foreground="#F1EFE8" Width="14" Height="14" Margin="0,0,9,0" VerticalAlignment="Center"/>
                        <TextBlock Grid.Column="1" Text="{Binding Label}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                        <Button x:Name="rm" Grid.Column="2" Style="{StaticResource IconBtn}" Padding="4" Tag="{Binding Key}" Visibility="Collapsed" ToolTip="Remove">
                          <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-x}" Width="11" Height="11"/>
                        </Button>
                      </Grid>
                      <DataTemplate.Triggers>
                        <MultiDataTrigger>
                          <MultiDataTrigger.Conditions>
                            <Condition Binding="{Binding IsMouseOver, ElementName=row}" Value="True"/>
                            <Condition Binding="{Binding CanEdit}" Value="True"/>
                          </MultiDataTrigger.Conditions>
                          <Setter TargetName="rm" Property="Visibility" Value="Visible"/>
                        </MultiDataTrigger>
                      </DataTemplate.Triggers>
                    </DataTemplate>
                  </ListBox.ItemTemplate>
                </ListBox>
              </Grid>
            </DockPanel>

            <DockPanel x:Name="WebPanel" Visibility="Collapsed">
              <Border x:Name="ModeBar" DockPanel.Dock="Top" Background="#383836" CornerRadius="6" Padding="2" Margin="0,2,0,6">
                <UniformGrid Columns="3">
                  <RadioButton x:Name="ModeOff" GroupName="WebMode" Style="{StaticResource Seg}" Content="Off"/>
                  <RadioButton x:Name="ModeAllow" GroupName="WebMode" Style="{StaticResource Seg}" Content="Allow Only"/>
                  <RadioButton x:Name="ModeBlock" GroupName="WebMode" Style="{StaticResource Seg}" Content="Block List"/>
                </UniformGrid>
              </Border>
              <Grid x:Name="SiteInputRow" DockPanel.Dock="Top" Margin="0,0,0,4">
                <TextBox x:Name="SiteInput" Padding="7,4,26,4"/>
                <TextBlock x:Name="SitePlaceholder" Foreground="#888780" FontSize="12" Margin="13,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
                <Button x:Name="AddSiteBtn" Style="{StaticResource IconBtn}" Padding="4" HorizontalAlignment="Right" Margin="0,0,3,0" ToolTip="Add">
                  <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-plus}" Width="12" Height="12"/>
                </Button>
              </Grid>
              <TextBlock x:Name="SiteNote" DockPanel.Dock="Top" FontSize="10.5" Foreground="#888780" TextWrapping="Wrap" Margin="2,0,2,3"/>
              <ListBox x:Name="SitesList" ItemContainerStyle="{StaticResource RowItem}">
                <ListBox.ItemTemplate>
                  <DataTemplate>
                    <Grid x:Name="row" Background="Transparent" Height="26">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                      <ContentControl Style="{StaticResource Ico}" Tag="{Binding Geo}" Foreground="#F1EFE8" Width="14" Height="14" Margin="0,0,9,0" VerticalAlignment="Center"/>
                      <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="{Binding Label}"/>
                        <TextBlock Text="{Binding Detail}" Foreground="#888780" FontSize="10.5" Margin="7,0,0,0" VerticalAlignment="Center"/>
                      </StackPanel>
                      <Button x:Name="rm" Grid.Column="2" Style="{StaticResource IconBtn}" Padding="4" Tag="{Binding Key}" Visibility="Collapsed" ToolTip="Remove">
                        <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-x}" Width="11" Height="11"/>
                      </Button>
                    </Grid>
                    <DataTemplate.Triggers>
                      <MultiDataTrigger>
                        <MultiDataTrigger.Conditions>
                          <Condition Binding="{Binding IsMouseOver, ElementName=row}" Value="True"/>
                          <Condition Binding="{Binding CanEdit}" Value="True"/>
                        </MultiDataTrigger.Conditions>
                        <Setter TargetName="rm" Property="Visibility" Value="Visible"/>
                      </MultiDataTrigger>
                    </DataTemplate.Triggers>
                  </DataTemplate>
                </ListBox.ItemTemplate>
              </ListBox>
            </DockPanel>
          </Grid>

          <Grid Grid.Row="4" Margin="0,8,0,0">
            <Button x:Name="StartBtn" Style="{StaticResource Primary}" Height="30" Content="Start 25-Minute Session"/>
            <Border x:Name="LockedBar" Background="#444441" CornerRadius="6" Height="30" Visibility="Collapsed">
              <TextBlock x:Name="LockedText" Foreground="#D3D1C7" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
          </Grid>
        </Grid>

        <DockPanel x:Name="PickerView" Grid.Row="1" Visibility="Collapsed" Background="#2C2C2A">
          <Grid DockPanel.Dock="Top" Margin="0,2,0,8">
            <Button x:Name="PickBack" Style="{StaticResource IconBtn}" HorizontalAlignment="Left" Margin="-5,0,0,0" Padding="5,4" ToolTip="Back">
              <StackPanel Orientation="Horizontal">
                <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-arrow-left}" Width="14" Height="14" Margin="0,0,7,0"/>
                <TextBlock Text="Add Applications" FontSize="13" FontWeight="SemiBold" Foreground="#F1EFE8"/>
              </StackPanel>
            </Button>
          </Grid>
          <Grid DockPanel.Dock="Top" Margin="0,0,0,6">
            <TextBox x:Name="PickSearch"/>
            <TextBlock x:Name="PickHint" Text="Search Your Applications" Foreground="#888780" FontSize="12" Margin="13,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
          </Grid>
          <Grid DockPanel.Dock="Bottom" Margin="0,8,0,0">
            <Button x:Name="PickBrowse" Style="{StaticResource RowBtn}" HorizontalAlignment="Left" Margin="-6,0,0,0">
              <StackPanel Orientation="Horizontal">
                <ContentControl Style="{StaticResource Ico}" Tag="{StaticResource i-folder}" Width="13" Height="13" Margin="0,0,7,0"/>
                <TextBlock Text="Browse Files"/>
              </StackPanel>
            </Button>
            <Button x:Name="PickAdd" Style="{StaticResource Primary}" HorizontalAlignment="Right" Content="Add" IsEnabled="False"/>
          </Grid>
          <TextBlock x:Name="PickNote" DockPanel.Dock="Bottom" FontSize="10.5" Foreground="#888780" Margin="2,5,0,0" Visibility="Collapsed"/>
          <ListBox x:Name="PickList" SelectionMode="Multiple" ItemContainerStyle="{StaticResource PickItem}">
            <ListBox.ItemTemplate>
              <DataTemplate>
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Image Source="{Binding Icon}" Width="20" Height="20" Margin="0,0,9,0" VerticalAlignment="Center" RenderOptions.BitmapScalingMode="HighQuality"/>
                  <TextBlock Grid.Column="1" Text="{Binding Label}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                  <ContentControl x:Name="tick" Grid.Column="2" Style="{StaticResource Ico}" Tag="{StaticResource i-check}" Foreground="#85B7EB" Width="13" Height="13" Visibility="Collapsed" VerticalAlignment="Center"/>
                </Grid>
                <DataTemplate.Triggers>
                  <DataTrigger Binding="{Binding IsSelected, RelativeSource={RelativeSource AncestorType=ListBoxItem}}" Value="True">
                    <Setter TargetName="tick" Property="Visibility" Value="Visible"/>
                  </DataTrigger>
                </DataTemplate.Triggers>
              </DataTemplate>
            </ListBox.ItemTemplate>
          </ListBox>
        </DockPanel>
      </Grid>

      <Border x:Name="DialogLayer" Background="#E6222220" CornerRadius="10" Visibility="Collapsed">
        <Border Background="#383836" BorderBrush="#4A4A47" BorderThickness="1" CornerRadius="8" Padding="14,12" Margin="12,0" VerticalAlignment="Center">
          <StackPanel>
            <ContentControl x:Name="DlgIcon" Style="{StaticResource Ico}" Width="18" Height="18" HorizontalAlignment="Left"/>
            <TextBlock x:Name="DlgTitle" FontSize="13.5" FontWeight="SemiBold" Margin="0,8,0,0" TextWrapping="Wrap"/>
            <TextBlock x:Name="DlgBody" FontSize="12" Foreground="#D3D1C7" Margin="0,5,0,0" TextWrapping="Wrap" LineHeight="17"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
              <Button x:Name="DlgSecondaryBtn" Style="{StaticResource Btn}" Margin="0,0,6,0"/>
              <Button x:Name="DlgPrimaryBtn" Style="{StaticResource Primary}"/>
            </StackPanel>
          </StackPanel>
        </Border>
      </Border>
    </Grid>
  </Border>
</Window>
'@)

foreach ($n in 'TitleBar','ScaleBtn','ScalePopup','ScaleTitle','ScaleList','PinBtn','PinIcon','MinBtn','CloseBtn','MainView','Arc','TimeText','SubText','DurRow','DurList','DurHint','DurInput','AddDurBtn',
               'TabApps','TabWeb','AppsPanel','AddAppRow','AppsEmpty','AppsList','WebPanel','ModeBar','ModeOff','ModeAllow','ModeBlock',
               'SiteInputRow','SiteInput','SitePlaceholder','AddSiteBtn','SiteNote','SitesList','StartBtn','LockedBar','LockedText',
               'PickerView','PickBack','PickSearch','PickHint','PickBrowse','PickAdd','PickNote','PickList',
               'DialogLayer','DlgIcon','DlgTitle','DlgBody','DlgSecondaryBtn','DlgPrimaryBtn') {
    Set-Variable -Name $n -Value $window.FindName($n) -Scope Script
}

# ---------- toast (start / end / blocked notices) ----------
$toast = [System.Windows.Markup.XamlReader]::Parse(@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False"
        ShowActivated="False" SizeToContent="WidthAndHeight" ResizeMode="NoResize"
        FontFamily="Segoe UI Variable Text, Segoe UI" TextOptions.TextFormattingMode="Display">
  <Border Background="#2C2C2A" BorderBrush="#444441" BorderThickness="1" CornerRadius="10" Padding="16,13" MinWidth="300" MaxWidth="380">
    <Grid>
      <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
      <ContentControl x:Name="ToastIcon" Style="{StaticResource Ico}" Width="20" Height="20" VerticalAlignment="Top" Margin="0,1,12,0"/>
      <StackPanel Grid.Column="1">
        <TextBlock x:Name="ToastTitle" FontSize="14" FontWeight="SemiBold" Foreground="#F1EFE8" TextWrapping="Wrap"/>
        <TextBlock x:Name="ToastBody" FontSize="12" Foreground="#B4B2A9" Margin="0,3,0,0" TextWrapping="Wrap"/>
      </StackPanel>
    </Grid>
  </Border>
</Window>
'@)
$ToastIcon = $toast.FindName('ToastIcon'); $ToastTitle = $toast.FindName('ToastTitle'); $ToastBody = $toast.FindName('ToastBody')
$toastTimer = New-Object System.Windows.Threading.DispatcherTimer
$toastTimer.Interval = [TimeSpan]::FromSeconds(3.5)
$toastTimer.Add_Tick({ $toastTimer.Stop(); $toast.Hide() })
$toast.Add_MouseLeftButtonDown({ $toastTimer.Stop(); $toast.Hide() })
$BrushConv = New-Object System.Windows.Media.BrushConverter

function Show-Toast([string]$icon, [string]$color, [string]$title, [string]$body) {
    $ToastIcon.Tag = $Geo[$icon]
    $ToastIcon.Foreground = $BrushConv.ConvertFromString($color)
    $ToastTitle.Text = $title
    $ToastBody.Text = $body
    $toast.Show()
    $wa = [System.Windows.SystemParameters]::WorkArea
    $toast.Left = $wa.Left + ($wa.Width - $toast.ActualWidth) / 2
    $toast.Top  = $wa.Top + $wa.Height * 0.08
    $toastTimer.Stop(); $toastTimer.Start()
}

# ---------- in-app dialog ----------
function Show-Dialog([string]$icon, [string]$color, [string]$title, [string]$body, [string]$primary, [scriptblock]$onPrimary,
                     [string]$secondary = '', [scriptblock]$onSecondary = $null) {
    Show-Main
    $DlgIcon.Tag = $Geo[$icon]
    $DlgIcon.Foreground = $BrushConv.ConvertFromString($color)
    $DlgTitle.Text = $title
    $DlgBody.Text = $body
    $DlgBody.Visibility = $(if ($body) { 'Visible' } else { 'Collapsed' })
    $DlgPrimaryBtn.Content = $primary
    $DlgSecondaryBtn.Content = $secondary
    $DlgSecondaryBtn.Visibility = $(if ($secondary) { 'Visible' } else { 'Collapsed' })
    $script:DlgPrimary = $onPrimary
    $script:DlgSecondary = $onSecondary
    $DialogLayer.Visibility = 'Visible'
}
function Close-Dialog([bool]$primary) {
    $DialogLayer.Visibility = 'Collapsed'
    $action = $script:DlgSecondary
    if ($primary) { $action = $script:DlgPrimary }
    $script:DlgPrimary = $null; $script:DlgSecondary = $null
    if ($action) { & $action }
}

# ---------- helpers ----------
function Format-Clock([TimeSpan]$t) {
    if ($t.TotalHours -ge 1) { '{0}:{1:00}:{2:00}' -f [int][Math]::Floor($t.TotalHours), $t.Minutes, $t.Seconds }
    else { '{0:00}:{1:00}' -f $t.Minutes, $t.Seconds }
}
function Format-Chip([int]$m) {
    if ($m -lt 60) { return "${m}m" }
    $h = [Math]::Floor($m / 60); $r = $m % 60
    if ($r -eq 0) { "${h}h" } else { "${h}h ${r}m" }
}

# The ring is a dashed circle whose dash covers the time left. During a session WPF animates the dash
# frame by frame, so it drains smoothly instead of stepping once a second.
$RingLen = [Math]::PI * (106 - 6) / 6.0          # circumference, in stroke-thickness units (106 px ring, 6 px stroke)
$RingDash = New-Object System.Windows.Media.DoubleCollection
$RingDash.Add($RingLen); $RingDash.Add($RingLen * 2)
$Arc.StrokeDashArray = $RingDash
$script:RingEnd = $null; $script:RingTotal = $null

function Set-Ring([double]$p) {
    $Arc.BeginAnimation([System.Windows.Shapes.Shape]::StrokeDashOffsetProperty, $null)   # stop any animation
    $script:RingEnd = $null
    $p = [Math]::Max(0.0, [Math]::Min(1.0, $p))   # 0.0/1.0, not 0/1: integer overloads would round
    $Arc.Visibility = $(if ($p -le 0.0005) { 'Hidden' } else { 'Visible' })
    $Arc.StrokeDashOffset = $RingLen * (1.0 - $p)
}

# Start (or correct) the smooth countdown so the ring reaches empty exactly at the session's end.
function Sync-Ring {
    if ($script:RingEnd -eq $script:SessionEnd -and $script:RingTotal -eq $script:SessionTotal) { return }
    $left = [Math]::Max(0.1, ($script:SessionEnd - [DateTime]::UtcNow).TotalSeconds)
    $p = [Math]::Max(0.0, [Math]::Min(1.0, $left / ([Math]::Max(1.0, [double]$script:SessionTotal) * 60.0)))
    $Arc.Visibility = 'Visible'
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation -ArgumentList ($RingLen * (1.0 - $p)), $RingLen,
        (New-Object System.Windows.Duration ([TimeSpan]::FromSeconds($left)))
    [System.Windows.Media.Animation.Timeline]::SetDesiredFrameRate($anim, 30)
    $Arc.BeginAnimation([System.Windows.Shapes.Shape]::StrokeDashOffsetProperty, $anim)
    $script:RingEnd = $script:SessionEnd; $script:RingTotal = $script:SessionTotal
}

function ConvertTo-ProcName([string]$s) {
    $n = $s.Trim().ToLower()
    if ($n.EndsWith('.exe')) { $n = $n.Substring(0, $n.Length - 4) }
    $n
}

function ConvertTo-ImageSource([System.Drawing.Icon]$ico) {
    $src = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($ico.Handle, [System.Windows.Int32Rect]::Empty,
        [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
    $src.Freeze(); $src
}
$DefaultIcon = ConvertTo-ImageSource ([System.Drawing.SystemIcons]::Application)

function Get-AppIcon([string]$path) {
    if (-not $path) { return $DefaultIcon }
    if ($script:IconCache.ContainsKey($path)) { return $script:IconCache[$path] }
    $img = $DefaultIcon
    if (Test-Path -LiteralPath $path) {
        try { $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($path); $img = ConvertTo-ImageSource $ico; $ico.Dispose() } catch {}
    }
    $script:IconCache[$path] = $img
    $img
}

function Get-AppGlyph($a) {
    $n = $a.Names[0]
    if ($AppGlyphs.ContainsKey($n)) { return $Geo[$AppGlyphs[$n]] }
    if ($a.Path -match 'steamapps|\\games\\|epic games|riot games' -or $n -match 'game') { return $Geo['device-gamepad-2'] }
    $Geo['app-window']
}

function Get-ProcNames([string]$name) {
    if ($AppAliases.ContainsKey($name)) { return @($AppAliases[$name]) }
    @($name)
}

# Installed apps (Start menu shortcuts) plus anything running with a window.
function Get-AppCandidates {
    $map = @{}
    $sh = New-Object -ComObject WScript.Shell
    $dirs = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs")
    foreach ($f in Get-ChildItem -Path $dirs -Recurse -Filter *.lnk -ErrorAction SilentlyContinue) {
        try { $l = $sh.CreateShortcut($f.FullName) } catch { continue }
        $target = $l.TargetPath
        if (-not $target -or -not $target.ToLower().EndsWith('.exe') -or -not (Test-Path -LiteralPath $target)) { continue }
        if ($target -like "$env:windir\*") { continue }   # built-in Windows tools
        $exe = [IO.Path]::GetFileNameWithoutExtension($target).ToLower()
        $path = $target
        if ($exe -eq 'update') {
            # Squirrel-installed apps (Discord, Discord Canary, ...) launch through Update.exe.
            if ($l.Arguments -notmatch '--processStart\s+"?([^"\s]+\.exe)') { continue }
            $real = $Matches[1]
            $exe = [IO.Path]::GetFileNameWithoutExtension($real).ToLower()
            $found = Get-ChildItem (Split-Path $target) -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName $real } |
                Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if ($found) { $path = $found }
        }
        if ($exe -match 'unins|uninstall|setup|installer|crashhandler|bugreport' -or $Protected -contains $exe) { continue }
        $names = @(Get-ProcNames $exe)
        if (-not $map.ContainsKey($names[0])) {
            $map[$names[0]] = [pscustomobject]@{ Label = $f.BaseName; Names = $names; Path = $path }
        }
    }
    foreach ($p in Get-Process | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }) {
        $n = $p.ProcessName.ToLower()
        if ($Protected -contains $n) { continue }
        $names = @(Get-ProcNames $n)
        if ($map.ContainsKey($names[0])) { continue }
        $path = $null; try { $path = $p.Path } catch {}
        $label = $null
        if ($path) { try { $label = (Get-Item -LiteralPath $path).VersionInfo.FileDescription } catch {} }
        if (-not $label) { $label = $p.ProcessName }
        $map[$names[0]] = [pscustomobject]@{ Label = $label.Trim(); Names = $names; Path = $path }
    }
    @($map.Values | Sort-Object Label)
}

# Fill in details for apps whose exe moved (Roblox and Discord update into new folders) or that only have a process name.
function Update-AppPaths {
    $missing = @($script:Apps | Where-Object { -not $_.Path -or -not (Test-Path -LiteralPath $_.Path) -or $_.Label -eq $_.Names[0] })
    if ($missing.Count -eq 0) { return }
    $cands = Get-AppCandidates
    foreach ($a in $missing) {
        $m = $cands | Where-Object { @($_.Names | Where-Object { $a.Names -contains $_ }).Count -gt 0 } | Select-Object -First 1
        if ($m) {
            $a.Path = $m.Path
            if ($a.Label -eq $a.Names[0]) { $a.Label = $m.Label }
        }
    }
    Update-AppsList
    Save-Config
}

function Get-SiteKey([string]$raw) {
    $s = $raw.Trim().ToLower() -replace '^[a-z]+://', '' -replace '^www\.', ''
    $s = ($s -split '[/?#]')[0] -replace '\s+', ' '
    if ($SiteNicknames.ContainsKey($s)) { $s = $SiteNicknames[$s] }
    if ($SiteDomains.Contains($s)) { return $s }
    foreach ($k in $SiteDomains.Keys) { if (@($SiteDomains[$k]) -contains $s) { return $k } }
    $s
}
function Resolve-Site([string]$raw) {
    $key = Get-SiteKey $raw
    if ($SiteDomains.Contains($key)) { return @($SiteDomains[$key]) }
    $clean = $key -replace '[^a-z0-9.\-]', ''
    if (-not $clean) { return @() }
    if ($clean -notmatch '\.') { $clean = "$clean.com" }
    @($clean)
}
function ConvertTo-FirefoxPattern([string]$d) {
    if ($d.Contains('/')) { $h, $p = $d.Split('/', 2); return "*://$h/$p*" }
    "*://*.$d/*"
}

# ---------- config ----------
function Save-Config {
    if ($script:Loading) { return }
    $ticks = $null
    if ($script:SessionEnd) { $ticks = $script:SessionEnd.Ticks }
    $obj = [ordered]@{
        apps               = @($script:Apps | ForEach-Object { [ordered]@{ label = $_.Label; names = @($_.Names); path = $_.Path } })
        minutes            = $script:Minutes
        durations          = @($script:Durations)
        webMode            = $script:WebMode
        allowSites         = @($script:AllowSites)
        blockSites         = @($script:BlockSites)
        sessionEndUtcTicks = $ticks
        sessionMinutes     = $script:SessionTotal
        sessionWebBlock    = [bool]$script:WebBlock
        blocked            = $script:BlockedCount
        sessionStrict      = [bool]$script:Strict
        pinned             = [bool]$script:Pinned
        scales             = $script:Scales
    }
    $obj | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8
}

function Load-Config {
    $cfg = $null
    if (Test-Path $ConfigPath) { try { $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json } catch {} }
    if (-not $cfg) {
        # First run defaults.
        [void]$script:Apps.Add([pscustomobject]@{ Label = 'Roblox'; Names = @('robloxplayerbeta', 'robloxplayerlauncher'); Path = $null })
        [void]$script:Apps.Add([pscustomobject]@{ Label = 'Discord Canary'; Names = @('discordcanary'); Path = $null })
        foreach ($s in 'whatsapp', 'google drive', 'google classroom') { [void]$script:AllowSites.Add($s) }
        [void]$script:BlockSites.Add('youtube')
        [void]$script:Durations.Add(25)
        return
    }
    foreach ($a in @($cfg.apps)) {
        if (-not $a) { continue }
        if ($a -is [string]) { [void]$script:Apps.Add([pscustomobject]@{ Label = $a; Names = @(Get-ProcNames $a); Path = $null }) }
        else { [void]$script:Apps.Add([pscustomobject]@{ Label = [string]$a.label; Names = @($a.names | ForEach-Object { [string]$_ }); Path = [string]$a.path }) }
    }
    if ($null -ne $cfg.allowSites) { foreach ($s in @($cfg.allowSites)) { if ($s) { [void]$script:AllowSites.Add([string]$s) } } }
    else { foreach ($s in 'whatsapp', 'google drive', 'google classroom') { [void]$script:AllowSites.Add($s) } }
    if ($null -ne $cfg.blockSites) { foreach ($s in @($cfg.blockSites)) { if ($s) { [void]$script:BlockSites.Add([string]$s) } } }
    if ($cfg.webMode) { $script:WebMode = [string]$cfg.webMode }
    elseif ($cfg.blockWebsites -eq $false) { $script:WebMode = 'off' }
    if ($cfg.minutes) { $script:Minutes = [Math]::Max(1, [Math]::Min(720, [int]$cfg.minutes)) }
    if ($null -ne $cfg.durations) { foreach ($d in @($cfg.durations)) { if ($d) { [void]$script:Durations.Add([int]$d) } } }
    elseif ($cfg.minutes) { [void]$script:Durations.Add($script:Minutes) }
    if ($cfg.blocked) { $script:BlockedCount = [int]$cfg.blocked }
    if ($cfg.sessionMinutes) { $script:SessionTotal = [int]$cfg.sessionMinutes }
    if ($cfg.sessionWebBlock) { $script:WebBlock = $true }
    if ($null -ne $cfg.pinned) { $script:Pinned = [bool]$cfg.pinned }
    if ($cfg.sessionStrict) { $script:Strict = $true }
    if ($cfg.scales) { foreach ($p in $cfg.scales.PSObject.Properties) { $script:Scales[$p.Name] = [string]$p.Value } }
    if ($cfg.sessionEndUtcTicks) {
        $end = New-Object DateTime ([long]$cfg.sessionEndUtcTicks), ([DateTimeKind]::Utc)
        if ($end -gt [DateTime]::UtcNow) { $script:SessionEnd = $end }
    }
}

# Re-launch Study Lock at sign-in only while a session is running, so a reboot doesn't end it.
function Set-Startup([bool]$on) {
    try {
        if ($on) {
            $sh  = New-Object -ComObject WScript.Shell
            $lnk = $sh.CreateShortcut($StartupLnk)
            $lnk.TargetPath  = (Join-Path $PSHOME 'powershell.exe')
            $lnk.Arguments   = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$PSCommandPath`" -Startup"
            $lnk.WindowStyle = 7
            $lnk.Save()
        } elseif (Test-Path $StartupLnk) {
            Remove-Item $StartupLnk -Force
        }
    } catch {}
}

# ---------- website blocking ----------
function Get-WebRules {
    if ($script:WebMode -eq 'allow') {
        $allow = @($script:AllowSites | ForEach-Object { Resolve-Site $_ })
        if (@($allow | Where-Object { $_ -like '*google.com*' }).Count -gt 0) { $allow += $GoogleSupport }
        $allow = @($allow | Select-Object -Unique)
        return @{ BlockChrome = @('*'); AllowChrome = $allow; BlockFirefox = @('*://*/*'); AllowFirefox = @($allow | ForEach-Object { ConvertTo-FirefoxPattern $_ }) }
    }
    $block = @($script:BlockSites | ForEach-Object { Resolve-Site $_ } | Select-Object -Unique)
    @{ BlockChrome = $block; AllowChrome = @(); BlockFirefox = @($block | ForEach-Object { ConvertTo-FirefoxPattern $_ }); AllowFirefox = @() }
}

# Builds the guard for the current settings and runs the starter elevated (one UAC prompt).
# Mode 'Start' begins a strict session of $Seconds; 'Clear' removes the guard and all website rules.
function Invoke-Guard([string]$Mode, [int]$Seconds = 0) {
    $quote = { param($list) (@($list) | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ', ' }
    $webOn = $script:WebMode -ne 'off'
    $rules = @{ BlockChrome = @(); AllowChrome = @(); BlockFirefox = @(); AllowFirefox = @() }
    if ($webOn) { $rules = Get-WebRules }
    $webCode = $WebRulesCode.Replace('__BLOCK_CHROME__', (& $quote $rules.BlockChrome))
    $webCode = $webCode.Replace('__ALLOW_CHROME__', (& $quote $rules.AllowChrome))
    $webCode = $webCode.Replace('__BLOCK_FIREFOX__', (& $quote $rules.BlockFirefox))
    $webCode = $webCode.Replace('__ALLOW_FIREFOX__', (& $quote $rules.AllowFirefox))
    $names = @($script:Apps | ForEach-Object { $_.Names })
    if ($webOn) { $names += $UnmanagedBrowsers }
    $webFlag = $(if ($webOn) { 'true' } else { 'false' })

    $guard = $GuardTemplate.Replace('__WEBRULES__', $webCode).Replace('__NAMES__', (& $quote ($names | Select-Object -Unique)))
    $guard = $guard.Replace('__WEBON__', $webFlag).Replace('__STATE__', $GuardState).Replace('__TASK__', $GuardTaskName)
    $guardB64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($guard))

    $text = $StarterTemplate.Replace('__WEBRULES__', $webCode).Replace('__GUARD_B64__', $guardB64)
    $text = $text.Replace('__DIR__', $GuardDir).Replace('__STATE__', $GuardState).Replace('__TASK__', $GuardTaskName)
    $text = $text.Replace('__WEBON__', $webFlag).Replace('__SECONDS__', [string]$Seconds)
    $file = Join-Path $DataDir 'starter.ps1'
    Set-Content -Path $file -Value $text -Encoding UTF8
    try {
        $p = Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -Wait -PassThru `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$file`" -Mode $Mode"
        return ($p.ExitCode -eq 0)
    } catch {
        return $false   # the admin prompt was declined
    } finally {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
    }
}

function Read-GuardState {
    if (-not (Test-Path $GuardState)) { return $null }
    try { Get-Content $GuardState -Raw -ErrorAction Stop | ConvertFrom-Json } catch { 'unreadable' }
}

function Test-WebPolicyActive {
    (Test-Path 'HKLM:\SOFTWARE\Policies\Google\Chrome\URLBlocklist') -or (Test-Path 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\WebsiteFilter')
}

# Firefox only reads website rules when it starts, so it has to be restarted (tabs come back).
function Restart-Firefox {
    if (-not (Get-Process firefox -ErrorAction SilentlyContinue)) { return }
    Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 1500
    if (Test-Path $FirefoxExe) { Start-Process $FirefoxExe }
}

# Returns a note for the summary if websites couldn't be unblocked.
function Unblock-WebsitesAfterSession {
    $script:OfferFirefox = $false
    if (-not $script:WebBlock) { return '' }
    $script:WebBlock = $false
    # The guard clears the rules when it finishes; give it a moment.
    for ($i = 0; $i -lt 10 -and (Test-WebPolicyActive); $i++) { Start-Sleep -Milliseconds 500 }
    if ((Test-WebPolicyActive) -and -not (Test-Path $GuardState)) { [void](Invoke-Guard 'Clear') }
    if (Test-WebPolicyActive) { return ' Websites are still blocked because the admin prompt was declined. Reopen Study Lock to try again.' }
    if (Get-Process firefox -ErrorAction SilentlyContinue) { $script:OfferFirefox = $true }
    ''
}

# ---------- lists ----------
function Update-AppsList {
    $edit = -not $script:SessionEnd
    $AppsList.ItemsSource = @(foreach ($a in $script:Apps) {
        [pscustomobject]@{ Label = $a.Label; Geo = (Get-AppGlyph $a); Key = $a.Names[0]; CanEdit = $edit }
    })
    $AppsEmpty.Visibility = $(if ($script:Apps.Count -eq 0) { 'Visible' } else { 'Collapsed' })
}

function Update-SitesList {
    $edit = -not $script:SessionEnd
    $list = $script:BlockSites
    if ($script:WebMode -eq 'allow') { $list = $script:AllowSites }
    $showList = $script:WebMode -ne 'off'
    $SitesList.ItemsSource = @(if ($showList) { foreach ($s in $list) {
        $key = Get-SiteKey $s
        $d = @(Resolve-Site $s)
        $label = $s; if ($SiteNames.ContainsKey($key)) { $label = $SiteNames[$key] }
        $glyph = $Geo['world']; if ($SiteGlyphs.ContainsKey($key)) { $glyph = $Geo[$SiteGlyphs[$key]] }
        $detail = ''
        if (-not $SiteNames.ContainsKey($key)) { $detail = $d[0] }
        [pscustomobject]@{ Label = $label; Detail = $detail; Geo = $glyph; Key = $s; CanEdit = $edit }
    } })
    $SitePlaceholder.Text = $(if ($script:WebMode -eq 'allow') { 'Allow a Site, Like Classroom' } else { 'Block a Site, Like YouTube' })
    $SiteInputRow.Visibility = $(if ($showList -and $edit) { 'Visible' } else { 'Collapsed' })
    $SiteNote.Text = switch ($script:WebMode) {
        'off'   { "Websites stay open during sessions." }
        'allow' { $(if ($list.Count -eq 0) { 'Nothing allowed yet, so every website will be blocked.' } else { '' }) }
        'block' { $(if ($list.Count -eq 0) { 'Add the sites you want blocked.' } else { '' }) }
    }
    $SiteNote.Visibility = $(if ($SiteNote.Text) { 'Visible' } else { 'Collapsed' })
}

function Update-Durations {
    $edit = -not $script:SessionEnd
    $sorted = @($script:Durations | Sort-Object -Unique)
    $DurList.ItemsSource = @(foreach ($m in $sorted) {
        $sel = ($m -eq $script:Minutes)
        [pscustomobject]@{
            Label = (Format-Chip $m); SelTag = "sel:$m"; RmTag = "rm:$m"
            Border = $(if ($sel) { '#378ADD' } else { '#5F5E5A' })
            Fg = $(if ($sel) { '#85B7EB' } else { '#D3D1C7' })
        }
    })
    $DurHint.Visibility = $(if ($sorted.Count -eq 0 -and $DurInput.Visibility -ne 'Visible') { 'Visible' } else { 'Collapsed' })
    $StartBtn.IsEnabled = $sorted.Count -gt 0
}

function Add-App($cand) {
    $key = $cand.Names[0]
    if (@($script:Apps | Where-Object { $_.Names[0] -eq $key }).Count -gt 0) { return }
    [void]$script:Apps.Add([pscustomobject]@{ Label = $cand.Label; Names = @($cand.Names); Path = $cand.Path })
}

function Add-Site {
    $raw = $SiteInput.Text
    if (-not $raw.Trim()) { return }
    $s = ($raw.Trim().ToLower() -replace '^[a-z]+://', '' -replace '^www\.', '' -replace '\s+', ' ').TrimEnd('/')
    if (@(Resolve-Site $s).Count -eq 0) { $SiteNote.Text = "That doesn't look like a website. Try youtube or example.com."; $SiteNote.Visibility = 'Visible'; return }
    $list = $script:BlockSites; if ($script:WebMode -eq 'allow') { $list = $script:AllowSites }
    $key = Get-SiteKey $s
    if (@($list | Where-Object { (Get-SiteKey $_) -eq $key }).Count -eq 0) { [void]$list.Add($s) }
    $SiteInput.Text = ''
    Update-SitesList; Save-Config
}

function ConvertFrom-DurationText([string]$t) {
    $t = $t.Trim().ToLower() -replace '\s+', ''
    if ($t -match '^(\d+)(m|min|mins|minutes)?$') { return [int]$Matches[1] }
    if ($t -match '^(\d+(?:\.\d+)?)(h|hr|hrs|hours?)$') { return [int][Math]::Round([double]$Matches[1] * 60) }
    if ($t -match '^(\d+)h(\d+)(m|min)?$') { return [int]$Matches[1] * 60 + [int]$Matches[2] }
    0
}
function Close-DurInput([bool]$commit) {
    if ($DurInput.Visibility -ne 'Visible') { return }
    if ($commit) {
        $m = ConvertFrom-DurationText $DurInput.Text
        if ($m -ge 1 -and $m -le 720) {
            if ($script:Durations -notcontains $m) { [void]$script:Durations.Add($m) }
            $script:Minutes = $m
        }
    }
    $DurInput.Text = ''
    $DurInput.Visibility = 'Collapsed'
    $AddDurBtn.Visibility = 'Visible'
    Update-Durations; Update-Clock; Save-Config
}

# ---------- app picker (inside the window) ----------
function Open-Picker {
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    $have = @($script:Apps | ForEach-Object { $_.Names[0] })
    $script:PickAll = @(Get-AppCandidates | Where-Object { $have -notcontains $_.Names[0] } | ForEach-Object {
        [pscustomobject]@{ Label = $_.Label; Names = $_.Names; Path = $_.Path; Icon = (Get-AppIcon $_.Path) }
    })
    $window.Cursor = $null
    $PickSearch.Text = ''
    $PickList.ItemsSource = $script:PickAll
    $PickNote.Text = ''; $PickNote.Visibility = 'Collapsed'
    $PickAdd.Content = 'Add'; $PickAdd.IsEnabled = $false
    $MainView.Visibility = 'Collapsed'
    $PickerView.Visibility = 'Visible'
    [void]$PickSearch.Focus()
}
function Close-Picker {
    $PickerView.Visibility = 'Collapsed'
    $MainView.Visibility = 'Visible'
    Update-AppsList; Save-Config
}

# ---------- session ----------
function Update-Clock {
    if ($script:SessionEnd) {
        $left = $script:SessionEnd - [DateTime]::UtcNow
        if ($left -lt [TimeSpan]::Zero) { $left = [TimeSpan]::Zero }
        $TimeText.Text = Format-Clock $left
        $SubText.Text = 'Left'
        Sync-Ring
        $tray.Text = "Study Lock - $(Format-Clock $left) Left"
    } elseif ($script:Durations.Count -eq 0) {
        $TimeText.Text = '--:--'
        $SubText.Text = 'No Length Set'
        Set-Ring 0
        $StartBtn.Content = 'Add a Session Length'
    } else {
        if ($script:Durations -notcontains $script:Minutes) { $script:Minutes = @($script:Durations | Sort-Object)[0] }
        $TimeText.Text = Format-Clock ([TimeSpan]::FromMinutes($script:Minutes))
        $SubText.Text = ''
        Set-Ring 1
        $StartBtn.Content = "Start $($script:Minutes)-Minute Session"
    }
    $SubText.Visibility = $(if ($SubText.Text) { 'Visible' } else { 'Collapsed' })
}

function Set-UiLocked([bool]$locked) {
    $show = 'Visible'; $hide = 'Collapsed'
    if ($locked) { $show = 'Collapsed'; $hide = 'Visible' }
    $DurRow.Visibility = $show
    $StartBtn.Visibility = $show
    $LockedBar.Visibility = $hide
    $AddAppRow.Visibility = $show
    $ModeBar.IsEnabled = -not $locked
    $miExit.Enabled = -not $locked
    if ($locked) { $LockedText.Text = "Locked Until $($script:SessionEnd.ToLocalTime().ToString('t'))" }
    else { $tray.Text = 'Study Lock' }
    Update-Durations; Update-AppsList; Update-SitesList; Update-Clock
}

function Show-BlockedToast([string[]]$hit) {
    $labels = @($hit | Where-Object { $_ } | Select-Object -Unique | ForEach-Object {
        $h = $_; $a = $script:Apps | Where-Object { $_.Names -contains $h } | Select-Object -First 1
        if ($a) { $a.Label } else { $h }
    } | Select-Object -Unique)
    if ($labels.Count -eq 0) { $labels = @('That application') }
    Show-Toast 'lock' '#F09595' "$($labels -join ', ') Is Locked" "$(Format-Clock ($script:SessionEnd - [DateTime]::UtcNow)) left. Back to studying."
}

# Strict sessions: follow the guard (time left, blocks) instead of enforcing here.
function Sync-Guard {
    $st = Read-GuardState
    if ($null -eq $st) {
        $script:GuardMisses++
        return ($script:GuardMisses -lt 3)          # gone for 3 checks in a row: the guard finished
    }
    if ($st -is [string]) { return $true }          # caught mid-write; try again next tick
    $script:GuardMisses = 0
    $age = ([DateTime]::UtcNow.Ticks - [long]$st.heartbeat) / 1e7
    if ($age -lt 0 -or $age -gt 30) { $age = 0 }    # stale or clock moved: trust the guard's own count
    $guardEnd = [DateTime]::UtcNow.AddSeconds([Math]::Max(0, [double]$st.remaining - $age))
    # only follow real drift (guard restarted, PC slept); ignore the second-or-so of rounding noise
    if (-not $script:SessionEnd -or [Math]::Abs(($guardEnd - $script:SessionEnd).TotalSeconds) -gt 2) { $script:SessionEnd = $guardEnd }
    if ([int]$st.total -gt 0) { $script:SessionTotal = [int]$st.total / 60.0 }
    if ([int]$st.blocked -gt $script:BlockedCount) {
        $script:BlockedCount = [int]$st.blocked
        Show-BlockedToast ("$($st.lastBlocked)".Split(','))
    }
    $true
}

function Invoke-Enforce {
    if ($script:Strict) { return }                  # the guard does this, as SYSTEM
    $names = @($script:Apps | ForEach-Object { $_.Names })
    if ($script:WebBlock) { $names += $UnmanagedBrowsers }
    if ($names.Count -eq 0) { return }
    $hit = @()
    foreach ($p in @(Get-Process -Name $names -ErrorAction SilentlyContinue)) {
        try { $p.Kill(); $hit += $p.ProcessName.ToLower() } catch {}
    }
    if ($hit.Count -eq 0) { return }
    # One launch often spawns several processes over a few ticks; count it once.
    if (([DateTime]::UtcNow - $script:LastBlock).TotalSeconds -gt 3) { $script:BlockedCount++; Save-Config }
    $script:LastBlock = [DateTime]::UtcNow
    Show-BlockedToast $hit
}

function Request-Session {
    $web = $script:WebMode
    if ($script:Durations.Count -eq 0) { return }
    if ($script:Apps.Count -eq 0 -and $web -eq 'off') {
        Show-Dialog 'alert-triangle' '#EF9F27' 'Nothing to Lock' 'Add an application, or turn on website blocking, first.' 'OK' $null
        return
    }
    if ($web -eq 'block' -and $script:BlockSites.Count -eq 0) {
        Show-Dialog 'alert-triangle' '#EF9F27' 'No Sites to Block' 'Add a site to your block list, or set Websites to Off.' 'OK' $null
        return
    }
    $lines = @()
    if ($script:Apps.Count -gt 0) { $lines += "Locked applications: $((@($script:Apps | ForEach-Object { $_.Label })) -join ', ')." }
    $siteLabel = { param($s) $k = Get-SiteKey $s; if ($SiteNames.ContainsKey($k)) { $SiteNames[$k] } else { $s } }
    if ($web -eq 'allow') { $lines += "Websites: only $((@($script:AllowSites | ForEach-Object { & $siteLabel $_ })) -join ', ')." }
    if ($web -eq 'block') { $lines += "Blocked sites: $((@($script:BlockSites | ForEach-Object { & $siteLabel $_ })) -join ', ')." }
    $note = 'Windows will ask for admin permission to lock the session down.'
    if ($web -ne 'off' -and (Get-Process firefox -ErrorAction SilentlyContinue)) { $note += ' Firefox will restart, and your tabs come back.' }
    $lines += $note
    $lines += "Open locked applications close right away, and the session can't be stopped early."
    Show-Dialog 'lock' '#85B7EB' "Start a $($script:Minutes)-Minute Session?" ($lines -join "`n`n") 'Start' { Start-Session } 'Not Yet' $null
}

function Start-Session {
    $script:SessionTotal = $script:Minutes
    $script:WebBlock = $false
    $script:Strict = $false
    if (Invoke-Guard 'Start' ($script:Minutes * 60)) {
        $script:Strict = $true
        $script:WebBlock = $script:WebMode -ne 'off'
        $script:SessionEnd = [DateTime]::UtcNow.AddMinutes($script:Minutes)
        if ($script:WebBlock) { Restart-Firefox }
        Complete-SessionStart
    } else {
        Show-Dialog 'alert-triangle' '#EF9F27' 'Admin Permission Needed' "Without it the session can't be locked down: closing Study Lock would end it, and websites can't be blocked.`n`nStart a basic session anyway?" 'Start Basic Session' {
            $script:SessionEnd = [DateTime]::UtcNow.AddMinutes($script:Minutes); Complete-SessionStart
        } 'Cancel' $null
    }
}

function Complete-SessionStart {
    $script:BlockedCount = 0
    $script:GuardMisses = 0
    $script:LastBlock = [DateTime]::MinValue
    Save-Config
    Set-Startup $true
    Set-UiLocked $true
    Invoke-Enforce
    $timer.Start()
    Show-Toast 'lock' '#85B7EB' 'Focus Session Started' "Locked until $($script:SessionEnd.ToLocalTime().ToString('t')). Closing the window keeps it running."
}

function Stop-Session {
    $timer.Stop()
    $script:SessionEnd = $null
    $script:Strict = $false
    Set-Startup $false
    $note = Unblock-WebsitesAfterSession
    Save-Config
    Set-UiLocked $false
    Show-Toast 'check' '#5DCAA5' 'Session Complete' 'Your applications and websites are unlocked.'
    $n = $script:BlockedCount
    $what = $(if ($n -eq 1) { '1 distraction' } else { "$n distractions" })
    Show-Dialog 'check' '#5DCAA5' 'Session Complete' "Nice work. You blocked $what.$note" 'Done' {
        if ($script:OfferFirefox) {
            Show-Dialog 'brand-firefox' '#85B7EB' 'Restart Firefox?' 'Firefox needs a restart before every website opens again. Your tabs come back.' 'Restart' { Restart-Firefox } 'Later' $null
        }
    }
}

# ---------- tray ----------
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Shield
$tray.Text = 'Study Lock'
$tray.Visible = $true
$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen = $trayMenu.Items.Add('Open Study Lock')
$miExit = $trayMenu.Items.Add('Exit')
$tray.ContextMenuStrip = $trayMenu

function Show-Main { $window.Show(); $window.WindowState = 'Normal'; [void]$window.Activate() }
function Exit-App {
    $script:Exiting = $true
    $timer.Stop(); $signalTimer.Stop()
    $tray.Visible = $false; $tray.Dispose()
    $toast.Close()
    $window.Close()
    $app.Shutdown()
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    if (-not $script:SessionEnd) { $timer.Stop(); return }
    if ($script:Strict) {
        if (-not (Sync-Guard)) { Stop-Session; return }
    } elseif (($script:SessionEnd - [DateTime]::UtcNow).TotalSeconds -le 0) { Stop-Session; return }
    Invoke-Enforce
    Update-Clock
})

# A second launch asks this copy to show itself.
$signalTimer = New-Object System.Windows.Threading.DispatcherTimer
$signalTimer.Interval = [TimeSpan]::FromMilliseconds(400)
$signalTimer.Add_Tick({ if ($showSignal.WaitOne(0)) { Show-Main } })

# ---------- events ----------
$TitleBar.Add_MouseLeftButtonDown({ $window.DragMove(); Update-Scale })
$MinBtn.Add_Click({ $window.WindowState = 'Minimized' })
$CloseBtn.Add_Click({ $window.Close() })
$window.Add_Closing({
    param($s, $e)
    if ($script:Exiting) { return }
    $e.Cancel = $true
    if ($script:SessionEnd) {
        $window.Hide()
        Show-Toast 'lock' '#85B7EB' 'Still Locked' "Study Lock keeps running in the tray until $($script:SessionEnd.ToLocalTime().ToString('t'))."
    } else {
        Exit-App
    }
})
$window.Add_KeyDown({
    param($s, $e)
    if ($e.Key -ne 'Escape') { return }
    if ($DialogLayer.Visibility -eq 'Visible') { if ($DlgSecondaryBtn.Visibility -eq 'Visible') { Close-Dialog $false } else { Close-Dialog $true } }
    elseif ($PickerView.Visibility -eq 'Visible') { Close-Picker }
})
$app.Add_SessionEnding({ $script:Exiting = $true })

$DlgPrimaryBtn.Add_Click({ Close-Dialog $true })
$DlgSecondaryBtn.Add_Click({ Close-Dialog $false })

$DurList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    if ($script:SessionEnd) { return }
    $tag = [string]$e.OriginalSource.Tag
    if ($tag -notmatch '^sel:(\d+)$') { return }
    $script:Minutes = [int]$Matches[1]
    Update-Durations; Update-Clock; Save-Config
})
# Right-click a length chip to remove it.
$DurList.Add_MouseRightButtonUp({
    param($s, $e)
    if ($script:SessionEnd) { return }
    $el = $e.OriginalSource
    while ($el -and -not ($el -is [System.Windows.Controls.Button] -and "$($el.Tag)" -like 'sel:*')) {
        $el = [System.Windows.Media.VisualTreeHelper]::GetParent($el)
    }
    if (-not $el) { return }
    $m = [int]("$($el.Tag)".Substring(4))
    while ($script:Durations -contains $m) { $script:Durations.Remove($m) }
    $e.Handled = $true
    Update-Durations; Update-Clock; Save-Config
})
function Set-Pinned([bool]$on) {
    $script:Pinned = $on
    $window.Topmost = $on
    $PinIcon.Tag = $(if ($on) { $Geo['pinned'] } else { $Geo['pin'] })
    $PinIcon.Foreground = $BrushConv.ConvertFromString($(if ($on) { '#85B7EB' } else { '#B4B2A9' }))
    $PinBtn.ToolTip = $(if ($on) { 'Kept on Top, Click to Unpin' } else { 'Keep on Top' })
}
$PinBtn.Add_Click({ Set-Pinned (-not $script:Pinned); Save-Config })

# ---------- size (remembered per monitor) ----------
$BaseWidth = 272; $BaseHeight = 392
$Scaler = New-Object System.Windows.Media.ScaleTransform 1.0, 1.0
$window.Content.LayoutTransform = $Scaler
$ScalePopup.Child.LayoutTransform = $Scaler
$toast.Content.LayoutTransform = $Scaler
$ScaleChoices = @('auto', '1', '1.25', '1.5', '1.75', '2')

function Get-CurrentScreen {
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $window).Handle
    [System.Windows.Forms.Screen]::FromHandle($hwnd)
}
function Get-ScreenKey { $b = (Get-CurrentScreen).Bounds; "$($b.Width)x$($b.Height)" }
# Auto: 100% at 1080 px tall, 125% at 1440, and so on (rounded to 25% steps).
function Get-AutoScale {
    $dpi = 1.0
    try { $dpi = [System.Windows.Media.VisualTreeHelper]::GetDpi($window).DpiScaleY } catch {}
    $h = (Get-CurrentScreen).Bounds.Height / $dpi
    [Math]::Max(1.0, [Math]::Min(2.0, [Math]::Round($h / 1080.0 * 4.0) / 4.0))
}
function Get-ScaleLabel([double]$s) { "$([int][Math]::Round($s * 100))%" }

function Update-Scale([bool]$recenter = $false) {
    $pref = $script:Scales[(Get-ScreenKey)]
    if (-not $pref) { $pref = 'auto' }
    $s = $(if ($pref -eq 'auto') { Get-AutoScale } else { [double]::Parse($pref, [Globalization.CultureInfo]::InvariantCulture) })
    $changed = $s -ne $Scaler.ScaleX
    $Scaler.ScaleX = $s; $Scaler.ScaleY = $s
    $window.Width = $BaseWidth * $s
    $window.Height = $BaseHeight * $s
    if ($changed -or $recenter) {
        # keep the window on its screen
        $dpi = 1.0; try { $dpi = [System.Windows.Media.VisualTreeHelper]::GetDpi($window).DpiScaleX } catch {}
        $wa = (Get-CurrentScreen).WorkingArea
        $l = $wa.Left / $dpi; $t = $wa.Top / $dpi; $w = $wa.Width / $dpi; $hh = $wa.Height / $dpi
        if ($recenter) { $window.Left = $l + ($w - $window.Width) / 2; $window.Top = $t + ($hh - $window.Height) / 2 }
        $window.Left = [Math]::Max($l, [Math]::Min($window.Left, $l + $w - $window.Width))
        $window.Top  = [Math]::Max($t, [Math]::Min($window.Top, $t + $hh - $window.Height))
    }
}

function Update-ScaleList {
    $pref = $script:Scales[(Get-ScreenKey)]
    if (-not $pref) { $pref = 'auto' }
    $ScaleList.ItemsSource = @(foreach ($c in $ScaleChoices) {
        $label = $(if ($c -eq 'auto') { "Auto ($(Get-ScaleLabel (Get-AutoScale)))" } else { Get-ScaleLabel ([double]::Parse($c, [Globalization.CultureInfo]::InvariantCulture)) })
        [pscustomobject]@{ Label = $label; Value = $c; Tick = $(if ($c -eq $pref) { 'Visible' } else { 'Collapsed' }) }
    })
    $b = (Get-CurrentScreen).Bounds
    $ScaleTitle.Text = "Size On This Screen ($($b.Width)x$($b.Height))"
}

$ScaleBtn.Add_Click({ Update-ScaleList; $ScalePopup.IsOpen = $true })
$ScaleList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    $v = [string]$e.OriginalSource.Tag
    if (-not $v) { return }
    $script:Scales[(Get-ScreenKey)] = $v
    $ScalePopup.IsOpen = $false
    Update-Scale
    Save-Config
})
# Apply the right size before the window first appears, and again whenever it's dragged to another screen.
$window.Add_SourceInitialized({ Update-Scale $true })
$AddDurBtn.Add_Click({
    $AddDurBtn.Visibility = 'Collapsed'
    $DurHint.Visibility = 'Collapsed'
    $DurInput.Visibility = 'Visible'
    [void]$DurInput.Focus()
})
$DurInput.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq 'Return') { Close-DurInput $true; $e.Handled = $true }
    elseif ($e.Key -eq 'Escape') { Close-DurInput $false; $e.Handled = $true }
})
$DurInput.Add_LostKeyboardFocus({ Close-DurInput $true })

$TabApps.Add_Checked({ $AppsPanel.Visibility = 'Visible'; $WebPanel.Visibility = 'Collapsed' })
$TabWeb.Add_Checked({ $AppsPanel.Visibility = 'Collapsed'; $WebPanel.Visibility = 'Visible' })

$ModeOff.Add_Checked({ $script:WebMode = 'off'; Update-SitesList; Save-Config })
$ModeAllow.Add_Checked({ $script:WebMode = 'allow'; Update-SitesList; Save-Config })
$ModeBlock.Add_Checked({ $script:WebMode = 'block'; Update-SitesList; Save-Config })

$SiteInput.Add_TextChanged({ $SitePlaceholder.Visibility = $(if ($SiteInput.Text) { 'Collapsed' } else { 'Visible' }) })
$SiteInput.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Return') { Add-Site; $e.Handled = $true } })
$AddSiteBtn.Add_Click({ Add-Site })

$AppsList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    if ($script:SessionEnd) { return }
    $key = [string]$e.OriginalSource.Tag
    foreach ($h in @($script:Apps | Where-Object { $_.Names[0] -eq $key })) { $script:Apps.Remove($h) }
    Update-AppsList; Save-Config
})
$SitesList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    if ($script:SessionEnd) { return }
    $key = [string]$e.OriginalSource.Tag
    if ($script:WebMode -eq 'allow') { $script:AllowSites.Remove($key) } else { $script:BlockSites.Remove($key) }
    Update-SitesList; Save-Config
})

$AddAppRow.Add_Click({
    try { Open-Picker }
    catch {
        $window.Cursor = $null
        "$(Get-Date -Format s)  $($_.Exception.Message)`r`n$($_.ScriptStackTrace)" | Add-Content (Join-Path $DataDir 'error.log')
        Show-Dialog 'alert-triangle' '#EF9F27' "Couldn't Load Your Applications" $_.Exception.Message 'OK' $null
    }
})
$PickBack.Add_Click({ Close-Picker })
$PickSearch.Add_TextChanged({
    $q = $PickSearch.Text.Trim().ToLower()
    $PickHint.Visibility = $(if ($PickSearch.Text) { 'Collapsed' } else { 'Visible' })
    $keep = @($PickList.SelectedItems)
    $PickList.ItemsSource = @($script:PickAll | Where-Object { -not $q -or $_.Label.ToLower().Contains($q) -or $_.Names[0].Contains($q) })
    foreach ($k in $keep) { if ($PickList.Items.Contains($k)) { [void]$PickList.SelectedItems.Add($k) } }
})
$PickList.Add_SelectionChanged({
    $n = $PickList.SelectedItems.Count
    $PickAdd.IsEnabled = $n -gt 0
    $PickAdd.Content = $(if ($n -gt 1) { "Add $n Applications" } else { 'Add' })
})
$PickAdd.Add_Click({
    foreach ($p in @($PickList.SelectedItems)) { Add-App $p }
    Close-Picker
})
$PickBrowse.Add_Click({
    $ofd = New-Object Microsoft.Win32.OpenFileDialog
    $ofd.Filter = 'Programs (*.exe)|*.exe'
    $ofd.InitialDirectory = $env:ProgramFiles
    if ($ofd.ShowDialog($window) -ne $true) { return }
    $n = ConvertTo-ProcName ([IO.Path]::GetFileNameWithoutExtension($ofd.FileName))
    if ($Protected -contains $n) { $PickNote.Text = "$n is part of Windows, so it can't be locked."; $PickNote.Visibility = 'Visible'; return }
    $label = $null; try { $label = (Get-Item -LiteralPath $ofd.FileName).VersionInfo.FileDescription } catch {}
    if (-not $label) { $label = $n }
    Add-App ([pscustomobject]@{ Label = $label.Trim(); Names = @(Get-ProcNames $n); Path = $ofd.FileName })
    Close-Picker
})

$StartBtn.Add_Click({ Request-Session })
$tray.Add_DoubleClick({ Show-Main })
$miOpen.Add_Click({ Show-Main })
$miExit.Add_Click({ if (-not $script:SessionEnd) { Exit-App } })

# ---------- launch ----------
Load-Config
switch ($script:WebMode) { 'off' { $ModeOff.IsChecked = $true } 'block' { $ModeBlock.IsChecked = $true } default { $ModeAllow.IsChecked = $true } }
Set-Pinned $script:Pinned
$script:Loading = $false

# For strict sessions the guard is the source of truth: its state can't be edited without admin rights,
# so changing Study Lock's own settings file doesn't end a session.
$st = Read-GuardState
if ($null -ne $st) {
    $script:Strict = $true
    if ($st -is [string]) { $script:SessionEnd = [DateTime]::UtcNow.AddMinutes(1) }   # re-read on the first tick
    else {
        $script:WebBlock = [bool]$st.webOn
        $script:BlockedCount = [int]$st.blocked
        $script:SessionTotal = [Math]::Max(1.0, [int]$st.total / 60.0)
        $script:SessionEnd = [DateTime]::UtcNow.AddSeconds([double]$st.remaining)
    }
} elseif ($script:Strict) {
    # The guard finished while Study Lock was closed.
    $script:Strict = $false
    $script:SessionEnd = $null
}

if ($script:SessionEnd) {
    # Resume a session that was running before a restart or relaunch.
    Set-UiLocked $true
    Set-Startup $true
    Invoke-Enforce
    $timer.Start()
} else {
    $script:WebBlock = $false
    Set-Startup $false
    if ($Startup) { $tray.Visible = $false; $tray.Dispose(); return }   # nothing to resume
    Set-UiLocked $false
}
Save-Config
$signalTimer.Start()

$window.Add_ContentRendered({
    Update-AppPaths
    if (-not $script:SessionEnd -and -not (Test-Path $GuardState) -and (Test-WebPolicyActive)) {
        # Safety net: no session is running, but website rules were left behind.
        Show-Dialog 'alert-triangle' '#EF9F27' 'Websites Are Still Blocked' 'An earlier session left websites blocked. Windows will ask for admin permission to unblock them.' 'Unblock' { [void](Invoke-Guard 'Clear') } 'Not Now' $null
    }
})
if (-not $Startup) { Show-Main } else { Update-AppPaths }
[void]$app.Run()
$mutex.ReleaseMutex()
