package io.github.shujaly.lockdown

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Does the locking during a session: sends locked apps and unsupported browsers to the home screen, steps back from
 * blocked websites, and keeps Lockdown's own settings and uninstall screens shut until time is up.
 */
class LockdownService : AccessibilityService() {
    companion object {
        @Volatile
        var running: LockdownService? = null

        private val SETTINGS = setOf("com.android.settings")
        private val INSTALLERS = setOf("com.google.android.packageinstaller", "com.android.packageinstaller", "com.samsung.android.packageinstaller")

        fun isEnabled(ctx: Context): Boolean {
            val me = ComponentName(ctx, LockdownService::class.java)
            val on = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
            return on.split(':').any { ComponentName.unflattenFromString(it) == me }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var active = false
    private var apps: Set<String> = emptySet()
    private var web: Sites.Rules? = null
    private var unmanaged: Set<String> = emptySet()
    private var lastBlock = 0L
    private var lastCount = 0L
    private val lastContent = HashMap<String, Long>()
    private var ticks = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
        Lock.init(this)
        running = this
        refresh()
    }

    override fun onDestroy() {
        running = null
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onInterrupt() {}

    /** Picks up a session that started or ended. Main thread. */
    fun refresh() {
        handler.removeCallbacks(tick)
        val s = Lock.session.value
        active = s != null
        if (s == null) {
            apps = emptySet(); web = null; unmanaged = emptySet()
            return
        }
        apps = s.apps.toSet()
        web = Sites.Rules(s.webMode, s.allow, s.block).takeIf { it.on }
        unmanaged = if (web != null) Browsers.unmanaged(this) else emptySet()
        Notify.session(this, Lock.remaining())
        handler.post(tick)
    }

    private val tick = object : Runnable {
        override fun run() {
            if (Lock.session.value == null) return refresh()
            if (Lock.remaining() <= 0) return Lock.finish()       // finish() calls refresh()
            if (++ticks % 5 == 0) Lock.checkpoint()
            // also look once a second, in case an app came forward without an event
            rootInActiveWindow?.packageName?.toString()?.let(::check)
            handler.postDelayed(this, 1000)
        }
    }

    override fun onAccessibilityEvent(e: AccessibilityEvent?) {
        if (!active || e == null) return
        val pkg = e.packageName?.toString() ?: return
        if (e.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val watched = (web != null && pkg in Browsers.managed) || pkg in SETTINGS || pkg in INSTALLERS
            if (!watched) return
            val now = SystemClock.elapsedRealtime()
            if (now - (lastContent[pkg] ?: 0L) < 400) return
            lastContent[pkg] = now
        }
        check(pkg)
    }

    private fun check(pkg: String) {
        if (pkg == packageName || SystemClock.elapsedRealtime() - lastBlock < 800) return
        when {
            pkg in apps -> block(BlockActivity.APP, Apps.label(this, pkg), home = true)
            web != null && pkg in unmanaged -> block(BlockActivity.BROWSER, Apps.label(this, pkg), home = true)
            web != null && pkg in Browsers.managed -> checkAddress(pkg)
            pkg in SETTINGS || pkg in INSTALLERS -> checkSelf(pkg)
        }
    }

    private fun checkAddress(pkg: String) {
        val rules = web ?: return
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != pkg) return
        val bar = Browsers.urlNode(root, pkg) ?: return
        if (bar.isFocused) return                           // still typing
        val (host, path) = Sites.parse(bar.text?.toString()) ?: return
        val hit = rules.blockedLabel(host, path) ?: return
        block(BlockActivity.SITE, hit, back = true)
    }

    /** Settings and uninstall screens that mention Lockdown stay closed during a session. */
    private fun checkSelf(pkg: String) {
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != pkg) return
        if (mentions(root, getString(R.string.app_name))) block(BlockActivity.SELF, getString(R.string.app_name), home = true)
    }

    /** Walks the screen ourselves: findAccessibilityNodeInfosByText misses text in Compose screens (newer Settings pages). */
    private fun mentions(root: AccessibilityNodeInfo, word: String): Boolean {
        val queue = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        var seen = 0
        while (queue.isNotEmpty() && seen++ < 800) {
            val n = queue.removeFirst()
            if (n.text?.contains(word, ignoreCase = true) == true || n.contentDescription?.contains(word, ignoreCase = true) == true) return true
            for (i in 0 until n.childCount) n.getChild(i)?.let(queue::add)
        }
        return false
    }

    private fun block(kind: String, label: String, home: Boolean = false, back: Boolean = false) {
        val now = SystemClock.elapsedRealtime()
        lastBlock = now
        if (home) performGlobalAction(GLOBAL_ACTION_HOME)
        if (back) performGlobalAction(GLOBAL_ACTION_BACK)
        // one attempt often fires several events; count it once
        if (kind != BlockActivity.SELF) {
            if (now - lastCount > 3000) Lock.addBlocked()
            lastCount = now
        }
        handler.postDelayed({ startActivity(BlockActivity.intent(this, kind, label)) }, 250)
    }
}
