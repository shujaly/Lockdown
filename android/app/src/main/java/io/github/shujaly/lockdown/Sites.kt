package io.github.shujaly.lockdown

/** Website keywords, the same table as the Windows app: type "youtube" and every domain YouTube uses is covered. */
object Sites {
    val domains: Map<String, List<String>> = linkedMapOf(
        "youtube" to listOf("youtube.com", "youtu.be", "youtube-nocookie.com", "youtubekids.com", "ytimg.com", "googlevideo.com"),
        "whatsapp" to listOf("whatsapp.com", "whatsapp.net", "wa.me"),
        "drive" to listOf("drive.google.com", "drive.usercontent.google.com", "docs.google.com", "lh3.google.com"),
        "classroom" to listOf("classroom.google.com", "docs.google.com", "drive.google.com", "drive.usercontent.google.com", "lh3.google.com"),
        "docs" to listOf("docs.google.com"),
        "gmail" to listOf("mail.google.com"),
        "tiktok" to listOf("tiktok.com", "tiktokcdn.com", "tiktokv.com"),
        "instagram" to listOf("instagram.com", "cdninstagram.com"),
        "facebook" to listOf("facebook.com", "fb.com", "fbcdn.net", "messenger.com"),
        "twitter" to listOf("twitter.com", "x.com", "twimg.com"),
        "reddit" to listOf("reddit.com", "redd.it", "redditmedia.com", "redditstatic.com"),
        "netflix" to listOf("netflix.com", "nflxvideo.net"),
        "twitch" to listOf("twitch.tv", "twitchcdn.net"),
        "roblox" to listOf("roblox.com", "rbxcdn.com"),
        "discord" to listOf("discord.com", "discord.gg", "discordapp.com", "discordapp.net"),
        "snapchat" to listOf("snapchat.com"),
        "pinterest" to listOf("pinterest.com", "pinimg.com"),
        "spotify" to listOf("spotify.com", "scdn.co"),
        "steam" to listOf("steampowered.com", "steamcommunity.com"),
        "chatgpt" to listOf("chatgpt.com", "openai.com"),
    )
    private val names = mapOf(
        "youtube" to "YouTube", "whatsapp" to "WhatsApp", "drive" to "Google Drive", "classroom" to "Google Classroom",
        "docs" to "Google Docs", "gmail" to "Gmail", "tiktok" to "TikTok", "instagram" to "Instagram", "facebook" to "Facebook",
        "twitter" to "X (Twitter)", "reddit" to "Reddit", "netflix" to "Netflix", "twitch" to "Twitch", "roblox" to "Roblox",
        "discord" to "Discord", "snapchat" to "Snapchat", "pinterest" to "Pinterest", "spotify" to "Spotify", "steam" to "Steam",
        "chatgpt" to "ChatGPT",
    )
    private val glyphs = mapOf(
        "youtube" to "brand-youtube", "whatsapp" to "brand-whatsapp", "drive" to "brand-google-drive", "classroom" to "school",
        "docs" to "file-text", "gmail" to "brand-gmail", "tiktok" to "brand-tiktok", "instagram" to "brand-instagram",
        "facebook" to "brand-facebook", "twitter" to "brand-x", "reddit" to "brand-reddit", "netflix" to "brand-netflix",
        "twitch" to "brand-twitch", "roblox" to "device-gamepad-2", "discord" to "brand-discord", "snapchat" to "brand-snapchat",
        "pinterest" to "brand-pinterest", "spotify" to "brand-spotify", "steam" to "brand-steam", "chatgpt" to "brand-openai",
    )
    private val nicknames = mapOf(
        "google drive" to "drive", "google classroom" to "classroom", "google docs" to "docs", "yt" to "youtube",
        "x" to "twitter", "insta" to "instagram", "ig" to "instagram", "fb" to "facebook", "snap" to "snapchat",
    )
    /**
     * Google sign-in, allowed automatically whenever a Google site is allowed. Signed out, Drive and Classroom send you
     * to workspace.google.com first, and its Sign In button is the way in.
     */
    private val googleSupport = listOf(
        "accounts.google.com", "www.google.com/accounts", "www.google.com/recaptcha", "accounts.youtube.com", "workspace.google.com",
    )

    private val scheme = Regex("^[a-z][a-z0-9+.-]*://")

    /** What the user typed, tidied: "https://www.YouTube.com/" -> "youtube.com". */
    fun clean(raw: String): String =
        raw.trim().lowercase().replace(scheme, "").removePrefix("www.").replace(Regex("\\s+"), " ").trimEnd('/')

    fun key(raw: String): String {
        var s = clean(raw).split('/', '?', '#')[0]
        nicknames[s]?.let { s = it }
        if (s in domains) return s
        for ((k, v) in domains) if (s in v) return k
        return s
    }

    fun resolve(raw: String): List<String> {
        val k = key(raw)
        domains[k]?.let { return it }
        var c = k.replace(Regex("[^a-z0-9.\\-]"), "")
        if (c.isEmpty()) return emptyList()
        if ('.' !in c) c = "$c.com"
        return listOf(c)
    }

    fun label(raw: String): String = names[key(raw)] ?: raw
    fun isNamed(raw: String) = key(raw) in names
    fun glyph(raw: String): String = glyphs[key(raw)] ?: "world"

    private fun isGoogle(d: String) = d.endsWith("google.com") || d.endsWith("youtube.com") || d == "youtu.be"

    /** Host and path from a browser's address bar, or null when it isn't showing a web address. */
    fun parse(text: String?): Pair<String, String>? {
        var t = text?.trim()?.lowercase() ?: return null
        if (t.isEmpty() || ' ' in t) return null
        t = t.replace(scheme, "")
        val end = t.indexOfFirst { it == '/' || it == '?' || it == '#' }.let { if (it < 0) t.length else it }
        val host = t.substring(0, end).substringAfterLast('@').substringBefore(':').trimEnd('.')
        if ('.' !in host || !host.matches(Regex("[a-z0-9.-]+"))) return null
        return host to t.substring(end)
    }

    fun matches(host: String, path: String, d: String): Boolean {
        val slash = d.indexOf('/')
        if (slash < 0) return host == d || host.endsWith(".$d")
        // Path rules need the path, which most browsers hide in the address bar; without it, they don't match.
        return host.removePrefix("www.") == d.substring(0, slash).removePrefix("www.") && path.startsWith(d.substring(slash))
    }

    class Rules(mode: String, allow: List<String>, block: List<String>) {
        val on = mode == "allow" || mode == "block"
        private val allowMode = mode == "allow"
        private val allowed: List<String> = allow.flatMap { resolve(it) }.let { d -> if (d.any(::isGoogle)) d + googleSupport else d }
        private val blocked: List<Pair<String, List<String>>> = block.map { label(it) to resolve(it) }

        /** The name to show when this address is blocked, or null when it's allowed. */
        fun blockedLabel(host: String, path: String): String? {
            if (!on) return null
            if (allowMode) return if (allowed.any { matches(host, path, it) }) null else host.removePrefix("www.")
            return blocked.firstOrNull { (_, ds) -> ds.any { matches(host, path, it) } }?.first
        }
    }
}
