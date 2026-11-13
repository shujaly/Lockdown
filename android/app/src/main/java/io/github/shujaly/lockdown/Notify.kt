package io.github.shujaly.lockdown

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/** The countdown shown while a session runs, and the message when it ends (the Windows app's tray and toasts). */
object Notify {
    private const val SESSION = "session"
    private const val DONE = "done"
    private const val ID_SESSION = 1
    private const val ID_DONE = 2

    private fun manager(ctx: Context): NotificationManager? {
        if (Build.VERSION.SDK_INT >= 33 &&
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return null
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(SESSION, "Focus Session", NotificationManager.IMPORTANCE_LOW))
        nm.createNotificationChannel(NotificationChannel(DONE, "Session Complete", NotificationManager.IMPORTANCE_DEFAULT))
        return nm
    }

    private fun open(ctx: Context) = PendingIntent.getActivity(
        ctx, 0, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), PendingIntent.FLAG_IMMUTABLE,
    )

    fun session(ctx: Context, remainingMs: Long) {
        val nm = manager(ctx) ?: return
        val end = System.currentTimeMillis() + remainingMs
        val n = Notification.Builder(ctx, SESSION)
            .setSmallIcon(R.drawable.ic_stat_lock)
            .setColor(0xFF378ADD.toInt())
            .setContentTitle("Focus Session")
            .setContentText("Locked until ${clockTime(ctx, end)}")
            .setWhen(end)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open(ctx))
            .build()
        nm.notify(ID_SESSION, n)
    }

    fun cancelSession(ctx: Context) {
        ctx.getSystemService(NotificationManager::class.java).cancel(ID_SESSION)
    }

    fun complete(ctx: Context) {
        val nm = manager(ctx) ?: return
        val n = Notification.Builder(ctx, DONE)
            .setSmallIcon(R.drawable.ic_stat_lock)
            .setColor(0xFF5DCAA5.toInt())
            .setContentTitle("Session Complete")
            .setContentText("Your applications and websites are unlocked.")
            .setAutoCancel(true)
            .setContentIntent(open(ctx))
            .build()
        nm.notify(ID_DONE, n)
    }
}
