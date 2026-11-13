package io.github.shujaly.lockdown

import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.provider.Settings
import kotlinx.coroutines.flow.MutableStateFlow
import org.json.JSONArray
import org.json.JSONObject

class LockdownApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Lock.init(this)
    }
}

/**
 * A running session. Times are on the uptime clock (elapsedRealtime), so changing the phone's clock does nothing.
 * After a reboot the uptime clock restarts, so the session resumes from the time left at its last checkpoint.
 */
data class Session(
    val total: Long,        // ms
    val end: Long,          // elapsedRealtime when it ends, this boot
    val boot: Int,
    val saved: Long,        // ms left at the last checkpoint
    val savedAt: Long,      // elapsedRealtime of the last checkpoint
    val apps: List<String>,
    val webMode: String,
    val allow: List<String>,
    val block: List<String>,
    val blocked: Int,
) {
    fun toJson(): String = JSONObject()
        .put("total", total).put("end", end).put("boot", boot).put("saved", saved).put("savedAt", savedAt)
        .put("apps", JSONArray(apps)).put("webMode", webMode).put("allow", JSONArray(allow)).put("block", JSONArray(block))
        .put("blocked", blocked).toString()

    companion object {
        private fun JSONArray.strings() = List(length()) { getString(it) }
        fun from(s: String): Session? = try {
            val o = JSONObject(s)
            Session(
                o.getLong("total"), o.getLong("end"), o.getInt("boot"), o.getLong("saved"), o.getLong("savedAt"),
                o.getJSONArray("apps").strings(), o.getString("webMode"), o.getJSONArray("allow").strings(),
                o.getJSONArray("block").strings(), o.getInt("blocked"),
            )
        } catch (e: Exception) {
            null
        }
    }
}

object Lock {
    private lateinit var app: Context
    private lateinit var prefs: SharedPreferences
    val session = MutableStateFlow<Session?>(null)
    /** Distractions blocked in the session that just ended, until the "Session Complete" message is shown; -1 otherwise. */
    val completed = MutableStateFlow(-1)

    @Synchronized
    fun init(ctx: Context) {
        if (::prefs.isInitialized) return
        app = ctx.applicationContext
        prefs = app.getSharedPreferences("session", Context.MODE_PRIVATE)
        completed.value = prefs.getInt("completed", -1)
        var s = prefs.getString("s", null)?.let(Session::from)
        if (s != null) {
            val now = SystemClock.elapsedRealtime()
            val boot = bootCount()
            if (s.boot != boot || now < s.savedAt) {
                s = s.copy(boot = boot, end = now + s.saved, savedAt = now)
                write(s)
            }
        }
        session.value = s
    }

    fun remaining(): Long = session.value?.let { (it.end - SystemClock.elapsedRealtime()).coerceAtLeast(0) } ?: 0

    @Synchronized
    fun start(minutes: Int, apps: List<String>, webMode: String, allow: List<String>, block: List<String>) {
        val now = SystemClock.elapsedRealtime()
        val total = minutes * 60_000L
        update(Session(total, now + total, bootCount(), total, now, apps, webMode, allow, block, 0))
        LockdownService.running?.refresh()
    }

    @Synchronized
    fun checkpoint() {
        val s = session.value ?: return
        val now = SystemClock.elapsedRealtime()
        update(s.copy(saved = (s.end - now).coerceAtLeast(0), savedAt = now))
    }

    @Synchronized
    fun addBlocked() {
        val s = session.value ?: return
        update(s.copy(blocked = s.blocked + 1))
    }

    @Synchronized
    fun finish() {
        val s = session.value ?: return
        prefs.edit().remove("s").putInt("completed", s.blocked).commit()
        session.value = null
        completed.value = s.blocked
        Notify.cancelSession(app)
        Notify.complete(app)
        LockdownService.running?.refresh()
    }

    fun clearCompleted() {
        prefs.edit().putInt("completed", -1).apply()
        completed.value = -1
    }

    private fun update(s: Session) {
        write(s)
        session.value = s
    }

    private fun write(s: Session) = prefs.edit().putString("s", s.toJson()).commit()

    private fun bootCount() = try {
        Settings.Global.getInt(app.contentResolver, Settings.Global.BOOT_COUNT)
    } catch (e: Exception) {
        -1
    }
}
