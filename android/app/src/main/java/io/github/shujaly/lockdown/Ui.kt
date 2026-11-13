package io.github.shujaly.lockdown

import android.content.Context
import android.text.format.DateFormat
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import java.util.Date

data class FolioColors(
    val paper: Color, val ink: Color, val muted: Color, val rule: Color,
    val soft: Color, val accent: Color, val onAccent: Color, val tint: Color, val error: Color,
)

private val daylight = FolioColors(
    Color(0xFFF7F3E9), Color(0xFF302E27), Color(0xFF655F53), Color(0xFFC9C0AD),
    Color(0xFFEFE9DA), Color(0xFF99432E), Color(0xFFFFF9EF), Color(0xFFF4E0D3), Color(0xFF982C24),
)
private val night = FolioColors(
    Color(0xFF292720), Color(0xFFF5F0E2), Color(0xFFC0B7A4), Color(0xFF504B3E),
    Color(0xFF332F26), Color(0xFFF3AA89), Color(0xFF361D14), Color(0xFF46352B), Color(0xFFFFAD9A),
)
val folio: FolioColors
    @Composable get() = if (isSystemInDarkTheme()) night else daylight

fun Modifier.bottomRule(color: Color, thickness: Dp = 1.dp) = drawBehind {
    val stroke = thickness.toPx()
    drawLine(color, Offset(0f, size.height - stroke / 2), Offset(size.width, size.height - stroke / 2), stroke)
}

@Composable
fun T(
    text: String, size: Int, color: Color = folio.ink, modifier: Modifier = Modifier,
    weight: FontWeight = FontWeight.Normal, lineHeight: Int = 0, maxLines: Int = Int.MAX_VALUE,
    family: FontFamily = FontFamily.SansSerif, tracking: TextUnit = TextUnit.Unspecified, tnum: Boolean = false,
) {
    BasicText(
        text, modifier,
        style = TextStyle(
            color = color, fontSize = size.sp, fontFamily = family, fontWeight = weight, letterSpacing = tracking,
            lineHeight = if (lineHeight > 0) lineHeight.sp else TextUnit.Unspecified,
            fontFeatureSettings = if (tnum) "lnum, tnum" else null,
        ),
        overflow = TextOverflow.Ellipsis, maxLines = maxLines,
    )
}

@Composable
fun PrimaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, lock: Boolean = false, onClick: () -> Unit) {
    Row(
        modifier.clip(RoundedCornerShape(4.dp)).background(if (enabled) folio.accent else folio.soft)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick).heightIn(min = 48.dp)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (lock) Ico("lock", if (enabled) folio.onAccent else folio.muted, 17.dp)
        T(text, 15, if (enabled) folio.onAccent else folio.muted, weight = FontWeight.SemiBold)
    }
}

@Composable
fun SecondaryButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(4.dp)).background(folio.soft)
            .clickable(role = Role.Button, onClick = onClick).heightIn(min = 48.dp).padding(horizontal = 12.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) { T(text, 15, weight = FontWeight.Medium) }
}

@Composable
fun IconBtn(name: String, label: String, color: Color = folio.muted, size: Dp = 17.dp, onClick: () -> Unit) {
    Box(
        Modifier.size(48.dp).clip(RoundedCornerShape(4.dp)).clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label }, contentAlignment = Alignment.Center,
    ) { Ico(name, color, size) }
}

class Dlg(
    val icon: String, val title: String, val body: String, val primary: String,
    val onPrimary: () -> Unit = {}, val secondary: String? = null, val onSecondary: () -> Unit = {},
    val summary: List<Pair<String, String>> = emptyList(), val note: String? = null,
)

@Composable
fun DialogLayer(d: Dlg, close: () -> Unit) {
    Dialog(onDismissRequest = close) {
        val shape = RoundedCornerShape(4.dp)
        Column(
            Modifier.widthIn(max = 460.dp).fillMaxWidth().clip(shape).background(folio.paper)
                .border(1.dp, folio.rule, shape).verticalScroll(rememberScrollState()).padding(20.dp),
        ) {
            if (d.summary.isEmpty()) Ico(d.icon, folio.accent, 23.dp, Modifier.padding(bottom = 10.dp))
            T(d.title, 26, family = FontFamily.Serif, tracking = (-0.6).sp)
            T(d.body, 15, folio.muted, Modifier.padding(top = 10.dp), lineHeight = 21)
            if (d.summary.isNotEmpty()) {
                Column(Modifier.fillMaxWidth().padding(top = 14.dp).bottomRule(folio.rule).padding(bottom = 9.dp)) {
                    Box(Modifier.fillMaxWidth().height(1.dp).background(folio.rule))
                    d.summary.forEach { (label, value) ->
                        Row(Modifier.fillMaxWidth().padding(top = 7.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            T(label, 13, modifier = Modifier.weight(.36f), weight = FontWeight.SemiBold)
                            T(value, 13, folio.muted, Modifier.weight(.64f), lineHeight = 18)
                        }
                    }
                }
            }
            d.note?.let { T(it, 14, folio.muted, Modifier.padding(top = 12.dp), lineHeight = 20) }
            Row(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                d.secondary?.let { SecondaryButton(it, Modifier.weight(.9f)) { close(); d.onSecondary() } }
                PrimaryButton(d.primary, Modifier.weight(1.2f), lock = d.summary.isNotEmpty()) { close(); d.onPrimary() }
            }
        }
    }
}

fun formatClock(ms: Long): String {
    val sec = (ms + 999) / 1000
    val h = sec / 3600
    val m = sec % 3600 / 60
    val s = sec % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%02d:%02d".format(m, s)
}

fun formatChip(m: Int) = when {
    m < 60 -> "${m}m"
    m % 60 == 0 -> "${m / 60}h"
    else -> "${m / 60}h ${m % 60}m"
}

/** "45", "45m", "1.5h", "1h30" -> minutes; 0 when it can't be read. */
fun parseDuration(text: String): Int {
    val t = text.trim().lowercase().replace(Regex("\\s+"), "")
    Regex("^(\\d+)(m|min|mins|minutes)?$").find(t)?.let { return it.groupValues[1].toIntOrNull() ?: 0 }
    Regex("^(\\d+(?:\\.\\d+)?)(h|hr|hrs|hour|hours)$").find(t)?.let { return Math.round(it.groupValues[1].toDouble() * 60).toInt() }
    Regex("^(\\d+)h(\\d+)(m|min)?$").find(t)?.let { return it.groupValues[1].toInt() * 60 + it.groupValues[2].toInt() }
    return 0
}

fun clockTime(ctx: Context, wallMs: Long): String = DateFormat.getTimeFormat(ctx).format(Date(wallMs))
