package io.github.shujaly.lockdown

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Rect
import android.net.Uri
import android.telecom.TelecomManager
import android.view.accessibility.AccessibilityNodeInfo
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.core.graphics.drawable.toBitmap

class AppEntry(val pkg: String, val label: String)

object Apps {
    private val labels = HashMap<String, String>()
    private val icons = HashMap<String, ImageBitmap?>()

    fun label(ctx: Context, pkg: String): String = synchronized(labels) {
        labels.getOrPut(pkg) {
            try {
                val pm = ctx.packageManager
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (e: Exception) {
                pkg
            }
        }
    }

    fun icon(ctx: Context, pkg: String): ImageBitmap? = synchronized(icons) {
        icons.getOrPut(pkg) {
            try {
                ctx.packageManager.getApplicationIcon(pkg).toBitmap(96, 96).asImageBitmap()
            } catch (e: Exception) {
                null
            }
        }
    }

    /** Apps that can never be locked: Lockdown, the home screen, Settings and the phone app. */
    fun protectedPackages(ctx: Context): Set<String> {
        val pm = ctx.packageManager
        val home = pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), PackageManager.MATCH_ALL)
            .map { it.activityInfo.packageName }
        val dialer = try {
            ctx.getSystemService(TelecomManager::class.java)?.defaultDialerPackage
        } catch (e: Exception) {
            null
        }
        return (home + listOfNotNull(dialer) + listOf(
            ctx.packageName, "com.android.settings", "com.android.systemui", "com.android.phone", "com.android.dialer",
            "com.google.android.dialer", "com.samsung.android.dialer", "com.android.emergency",
        )).toSet()
    }

    /** Installed apps with a launcher icon, minus protected ones, with their icons loaded. Call off the main thread. */
    fun launchable(ctx: Context): List<AppEntry> {
        val pm = ctx.packageManager
        val skip = protectedPackages(ctx)
        return pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .map { it.activityInfo.packageName }
            .distinct()
            .filter { it !in skip }
            .map { AppEntry(it, label(ctx, it)).also { e -> icon(ctx, e.pkg) } }
            .sortedBy { it.label.lowercase() }
    }
}

object Browsers {
    /** Browsers whose address bar Lockdown can read, with the view IDs of that bar. Others are locked while websites are. */
    val managed: Map<String, List<String>> = buildMap {
        for (p in listOf(
            "com.android.chrome", "com.chrome.beta", "com.chrome.dev", "com.chrome.canary", "org.chromium.chrome",
            "com.brave.browser", "com.brave.browser_beta", "com.microsoft.emmx", "com.microsoft.emmx.beta",
            "com.vivaldi.browser", "com.kiwibrowser.browser",
        )) put(p, listOf("url_bar"))
        for (p in listOf("com.sec.android.app.sbrowser", "com.sec.android.app.sbrowser.beta")) put(p, listOf("location_bar_edit_text"))
        for (p in listOf("org.mozilla.firefox", "org.mozilla.firefox_beta", "org.mozilla.fenix")) {
            put(p, listOf("mozac_browser_toolbar_url_view", "url_bar_title"))
        }
        put("com.opera.browser", listOf("url_field"))
        put("com.duckduckgo.mobile.android", listOf("omnibarTextInput"))
    }

    /** Every other installed app that opens web links. */
    fun unmanaged(ctx: Context): Set<String> {
        val skip = Apps.protectedPackages(ctx)
        return ctx.packageManager.queryIntentActivities(Intent(Intent.ACTION_VIEW, Uri.parse("http://example.com")), PackageManager.MATCH_ALL)
            .map { it.activityInfo.packageName }
            .filter { it !in managed && it !in skip }
            .toSet()
    }

    /** The address bar of a known browser, or the first web-address text field near the top or bottom of the screen. */
    fun urlNode(root: AccessibilityNodeInfo, pkg: String): AccessibilityNodeInfo? {
        for (id in managed[pkg].orEmpty()) {
            root.findAccessibilityNodeInfosByViewId("$pkg:id/$id").firstOrNull()?.let { return it }
        }
        val screen = Rect().also { root.getBoundsInScreen(it) }
        val edge = screen.height() / 5
        val queue = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        var seen = 0
        while (queue.isNotEmpty() && seen++ < 400) {
            val n = queue.removeFirst()
            val field = n.className?.endsWith("EditText") == true || n.viewIdResourceName?.contains("url", ignoreCase = true) == true
            if (field && Sites.parse(n.text?.toString()) != null) {
                val b = Rect().also { n.getBoundsInScreen(it) }
                if (b.top < screen.top + edge || b.bottom > screen.bottom - edge) return n
            }
            for (i in 0 until n.childCount) n.getChild(i)?.let(queue::add)
        }
        return null
    }
}
