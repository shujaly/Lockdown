package io.github.shujaly.lockdown

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

/** Shown over a locked app or website, like the Windows app's "… Is Locked" notice. */
class BlockActivity : ComponentActivity() {
    companion object {
        const val APP = "app"
        const val BROWSER = "browser"
        const val SITE = "site"
        const val SELF = "self"

        fun intent(ctx: Context, kind: String, label: String): Intent = Intent(ctx, BlockActivity::class.java)
            .putExtra("kind", kind).putExtra("label", label)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }

    private var kind by mutableStateOf(APP)
    private var label by mutableStateOf("")

    private fun read(i: Intent) {
        kind = i.getStringExtra("kind") ?: APP
        label = i.getStringExtra("label") ?: ""
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        read(intent)
        setContent { BlockScreen(kind, label) { finish() } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        read(intent)
    }
}

@Composable
private fun BlockScreen(kind: String, label: String, done: () -> Unit) {
    BackHandler(onBack = done)
    val left by produceState(Lock.remaining()) {
        while (true) {
            value = Lock.remaining()
            delay(250)
        }
    }
    val title = when (kind) {
        BlockActivity.SITE -> "$label is blocked"
        BlockActivity.SELF -> "Lockdown is protected"
        else -> "$label is locked"
    }
    val detail = when (kind) {
        BlockActivity.BROWSER -> "This browser can’t follow website rules. It stays locked until the session ends."
        BlockActivity.SELF -> "Lockdown’s settings and uninstall stay locked until the session ends."
        else -> null
    }
    Box(Modifier.fillMaxSize().background(folio.paper).systemBarsPadding().padding(20.dp), contentAlignment = Alignment.Center) {
        val shape = RoundedCornerShape(4.dp)
        Column(Modifier.widthIn(max = 460.dp).fillMaxWidth().clip(shape).background(folio.paper)
            .border(1.dp, folio.rule, shape).verticalScroll(rememberScrollState()).padding(22.dp)) {
            Box(Modifier.background(folio.accent, shape).padding(7.dp)) { Ico("lock", folio.onAccent, 21.dp) }
            T(title, 28, family = FontFamily.Serif, tracking = (-.6).sp, modifier = Modifier.padding(top = 14.dp))
            detail?.let { T(it, 15, folio.muted, Modifier.padding(top = 8.dp), lineHeight = 21) }
            T("TIME REMAINING", 11, folio.accent, Modifier.padding(top = 20.dp), tracking = 1.25.sp)
            T(formatClock(left), 48, family = FontFamily.Serif, tracking = (-1.4).sp, tnum = true)
            PrimaryButton("OK", Modifier.fillMaxWidth().padding(top = 18.dp), onClick = done)
        }
    }
}
