package io.github.shujaly.lockdown

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.json.JSONArray

class MainActivity : ComponentActivity() {
    /** Bumped on every resume, so the screen re-checks whether the accessibility service is on. */
    var resumes by mutableIntStateOf(0)

    private val notifications = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted && Lock.session.value != null) Notify.session(this, Lock.remaining())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { LockdownScreen(this) }
    }

    override fun onResume() {
        super.onResume()
        resumes++
    }

    fun askNotifications() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}

/** What you set up between sessions, kept in the app's private storage. */
class Config(ctx: Context) {
    private val p = ctx.getSharedPreferences("config", Context.MODE_PRIVATE)
    private fun strings(k: String): List<String>? =
        p.getString(k, null)?.let { s -> JSONArray(s).let { a -> List(a.length()) { a.getString(it) } } }

    var apps by mutableStateOf(strings("apps") ?: emptyList())
    var durations by mutableStateOf(strings("durations")?.mapNotNull { it.toIntOrNull() } ?: listOf(25, 45, 90))
    var minutes by mutableIntStateOf(p.getInt("minutes", 25))
    var webMode by mutableStateOf(p.getString("webMode", null) ?: "allow")
    var allowSites by mutableStateOf(strings("allowSites") ?: listOf("whatsapp", "google drive", "google classroom"))
    var blockSites by mutableStateOf(strings("blockSites") ?: listOf("youtube", "tiktok", "instagram"))

    fun save() {
        p.edit()
            .putString("apps", JSONArray(apps).toString())
            .putString("durations", JSONArray(durations.map { it.toString() }).toString())
            .putInt("minutes", minutes)
            .putString("webMode", webMode)
            .putString("allowSites", JSONArray(allowSites).toString())
            .putString("blockSites", JSONArray(blockSites).toString())
            .apply()
    }
}

private fun openAccessibility(ctx: Context) {
    val details = Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS")
        .putExtra(Intent.EXTRA_COMPONENT_NAME, android.content.ComponentName(ctx, LockdownService::class.java).flattenToString())
    try {
        ctx.startActivity(details)
    } catch (e: Exception) {
        ctx.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }
}

private fun openAppInfo(ctx: Context) {
    ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", ctx.packageName, null)))
}

@Composable
fun LockdownScreen(act: MainActivity) {
    val ctx = LocalContext.current
    val cfg = remember { Config(ctx) }
    val session by Lock.session.collectAsState()
    val completed by Lock.completed.collectAsState()
    var dialog by remember { mutableStateOf<Dlg?>(null) }
    var editor by rememberSaveable { mutableStateOf<String?>(null) }
    var picking by rememberSaveable { mutableStateOf(false) }
    var tab by rememberSaveable { mutableIntStateOf(0) }
    val serviceOn = remember(act.resumes, session) { LockdownService.isEnabled(ctx) }
    val locked = session != null
    val appList = session?.apps ?: cfg.apps
    val mode = session?.webMode ?: cfg.webMode
    val sites = when (mode) {
        "allow" -> session?.allow ?: cfg.allowSites
        "block" -> session?.block ?: cfg.blockSites
        else -> emptyList()
    }

    LaunchedEffect(locked) {
        while (locked) {
            if (Lock.remaining() <= 0L) Lock.finish()
            delay(500)
        }
    }
    LaunchedEffect(completed) {
        if (completed < 0) return@LaunchedEffect
        val what = if (completed == 1) "1 distraction" else "$completed distractions"
        dialog = Dlg("check", "Session complete", "Nice work. You blocked $what.", "Done")
        Lock.clearCompleted()
    }

    fun warn(title: String, body: String) {
        dialog = Dlg("alert-triangle", title, body, "OK")
    }

    fun requestSession() {
        if (cfg.apps.isEmpty() && cfg.webMode == "off") return warn("Nothing to lock", "Add an application or turn on website blocking first.")
        if (cfg.webMode == "block" && cfg.blockSites.isEmpty()) return warn("No sites to block", "Add a site to your block list or set Websites to Off.")
        if (!LockdownService.isEnabled(ctx)) {
            dialog = Dlg(
                "alert-triangle", "Turn on Lockdown",
                "Lockdown uses Android's accessibility service to close locked applications and websites. It only looks at which app is open and, in browsers, the address bar.\n\n" +
                    "Open Settings, tap Lockdown (it may be under Downloaded Apps) and turn it on.\n\n" +
                    "If Android says it's a restricted setting, open App Info, tap ⋮ and choose Allow Restricted Settings, then try again.",
                "Open Settings", { openAccessibility(ctx) }, "App Info", { openAppInfo(ctx) },
            )
            return
        }
        val webSummary = when (mode) {
            "allow" -> if (sites.isEmpty()) "Block all sites" else "Allow only " + sites.joinToString { Sites.label(it) }
            "block" -> "Block " + sites.joinToString { Sites.label(it) }
            else -> "Off"
        }
        val until = clockTime(ctx, System.currentTimeMillis() + cfg.minutes * 60_000L)
        dialog = Dlg(
            "lock", "Start a ${cfg.minutes}-minute session?", "Once started, the session runs until $until. You can’t end it early.",
            "Start session", {
                Lock.start(cfg.minutes, cfg.apps, cfg.webMode, cfg.allowSites, cfg.blockSites)
                act.askNotifications()
            }, "Not yet",
            summary = listOf("Applications" to appList.joinToString { Apps.label(ctx, it) }.ifEmpty { "None" }, "Websites" to webSummary),
            note = if (mode == "off") "Selected apps lock immediately." else
                "Selected apps and website rules take effect immediately. Browsers that can’t follow website rules are locked for the session.",
        )
    }

    Box(Modifier.fillMaxSize().background(folio.paper).systemBarsPadding().imePadding(), contentAlignment = Alignment.TopCenter) {
        Column(Modifier.widthIn(max = 560.dp).fillMaxSize()) {
            if (picking && !locked) {
                Box(Modifier.fillMaxSize().padding(horizontal = 20.dp)) { Picker(cfg) { picking = false } }
            } else {
                Header()
                Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
                    LazyColumn(Modifier.weight(1f).fillMaxWidth()) {
                        item { SessionFace(cfg, session) }
                        if (!locked) item {
                            DurationRow(cfg, { editor = "duration" }) { m ->
                                dialog = Dlg("clock", "Remove ${formatChip(m)}?", "It won't show up as a session length anymore.", "Remove", {
                                    cfg.durations = cfg.durations - m
                                    if (cfg.minutes == m) cfg.minutes = cfg.durations.minOrNull() ?: cfg.minutes
                                    cfg.save()
                                }, "Cancel")
                            }
                        }
                        item { Tabs(tab, appList.size, sites.size) { tab = it } }
                        if (tab == 0) {
                            if (appList.isEmpty()) item { Help("No applications selected.") }
                            items(appList, key = { "app:$it" }) { pkg ->
                                val label = Apps.label(ctx, pkg)
                                RowLine(label, { AppIcon(pkg, 27.dp) }, locked = locked) {
                                    cfg.apps = cfg.apps - pkg; cfg.save()
                                }
                            }
                            if (!locked) item { AddRow("Add application") { picking = true } }
                        } else {
                            item {
                                if (locked) Help(when (mode) {
                                    "allow" -> "Allow only these websites"
                                    "block" -> "Block only these websites"
                                    else -> "Website blocking is off."
                                }) else WebModes(mode) { cfg.webMode = it; cfg.save() }
                            }
                            if (mode == "off" && !locked) item { Help("All websites are available during this session.") }
                            if (mode != "off") {
                                if (sites.isEmpty()) item { Help(if (mode == "allow") "All websites will be blocked." else "No websites selected.") }
                                items(sites, key = { "site:$it" }) { site ->
                                    val detail = if (Sites.isNamed(site)) null else Sites.resolve(site).firstOrNull()?.takeIf { it != site }
                                    RowLine(Sites.label(site), {
                                        Box(Modifier.size(27.dp).background(folio.soft, RoundedCornerShape(5.dp)), contentAlignment = Alignment.Center) {
                                            Ico(Sites.glyph(site), folio.muted, 18.dp)
                                        }
                                    }, detail, locked, allowed = mode == "allow") {
                                        if (mode == "allow") cfg.allowSites = cfg.allowSites - site else cfg.blockSites = cfg.blockSites - site
                                        cfg.save()
                                    }
                                }
                                if (!locked) item { AddRow("Add website") { editor = "website" } }
                            }
                        }
                    }
                    if (locked && !serviceOn) {
                        Row(
                            Modifier.fillMaxWidth().padding(top = 6.dp).background(folio.tint, RoundedCornerShape(4.dp))
                                .clickable { openAccessibility(ctx) }.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Ico("alert-triangle", folio.accent, 18.dp)
                            T("Lockdown’s accessibility service is off. Tap to turn blocking back on.", 14, folio.ink)
                        }
                    }
                    if (locked) {
                        val until = remember(session?.end) { clockTime(ctx, System.currentTimeMillis() + Lock.remaining()) }
                        Box(Modifier.fillMaxWidth().height(1.dp).background(folio.rule))
                        Row(Modifier.fillMaxWidth().padding(vertical = 18.dp), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                            Ico("lock", folio.muted, 16.dp)
                            T("Locked until $until", 14, folio.muted)
                        }
                    } else {
                        val has = cfg.durations.isNotEmpty()
                        PrimaryButton(if (has) "Start ${cfg.minutes}-minute session" else "Add a session length",
                            Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 16.dp), enabled = has, lock = true) { requestSession() }
                    }
                }
            }
        }
        dialog?.let { DialogLayer(it) { dialog = null } }
        editor?.takeUnless { locked }?.let { which ->
            EntryDialog(duration = which == "duration", allow = mode == "allow", close = { editor = null }) { entry ->
                if (which == "duration") {
                    val minutes = parseDuration(entry)
                    if (minutes !in 1..720) return@EntryDialog "Enter a duration between 1 minute and 12 hours."
                    if (minutes !in cfg.durations) cfg.durations = cfg.durations + minutes
                    cfg.minutes = minutes
                } else {
                    val site = Sites.clean(entry)
                    if (site.isEmpty() || Sites.resolve(site).isEmpty()) return@EntryDialog "Enter a site name or domain, like youtube or example.com."
                    if (sites.none { Sites.key(it) == Sites.key(site) }) {
                        if (mode == "allow") cfg.allowSites = cfg.allowSites + site else cfg.blockSites = cfg.blockSites + site
                    }
                }
                cfg.save()
                editor = null
                null
            }
        }
    }
}

@Composable
private fun Header() {
    Row(Modifier.fillMaxWidth().bottomRule(folio.rule).padding(horizontal = 20.dp).height(55.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(26.dp).background(folio.accent, RoundedCornerShape(3.dp)), contentAlignment = Alignment.Center) {
            Ico("lock", folio.onAccent, 18.dp)
        }
        T("Lockdown", 23, family = FontFamily.Serif, weight = FontWeight.Bold, tracking = (-.7).sp)
    }
}

@Composable
private fun SessionFace(cfg: Config, session: Session?) {
    val end = session?.end
    var now by remember(end) { mutableLongStateOf(SystemClock.elapsedRealtime()) }
    LaunchedEffect(end) {
        if (end != null) while (true) {
            now = SystemClock.elapsedRealtime()
            delay(((end - now).coerceAtLeast(0) % 1000).coerceAtLeast(50))
        }
    }
    val time = when {
        end != null -> formatClock((end - now).coerceAtLeast(0))
        cfg.durations.isEmpty() -> "--:--"
        else -> formatClock(cfg.minutes * 60_000L)
    }
    val caption = when {
        end != null -> "TIME REMAINING"
        cfg.durations.isEmpty() -> "NO LENGTH SET"
        else -> "SESSION LENGTH"
    }
    val progress = when {
        session != null -> ((session.end - now).toDouble() / session.total.coerceAtLeast(1)).toFloat().coerceIn(0f, 1f)
        cfg.durations.isEmpty() -> 0f
        else -> 1f
    }
    val colors = folio
    BoxWithConstraints(
        Modifier.fillMaxWidth().bottomRule(colors.ink).padding(vertical = if (session == null) 14.dp else 23.dp),
    ) {
        val fontScale = LocalDensity.current.fontScale
        val fittingSize = ((maxWidth.value - 34f) / (time.length * .56f) / fontScale).coerceAtLeast(20f)
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                T(caption, 11, colors.accent, weight = FontWeight.SemiBold, tracking = 1.25.sp)
                T(time, minOf(74f, fittingSize).toInt(), colors.ink, family = FontFamily.Serif, tracking = (-2.8).sp, maxLines = 1, tnum = true)
            }
            Canvas(Modifier.width(24.dp).height(78.dp)) {
                val x = size.width - 4.dp.toPx()
                val inset = 2.dp.toPx()
                val height = size.height - inset * 2
                drawLine(colors.rule, Offset(x, inset), Offset(x, inset + height), 1.dp.toPx())
                for (i in 0..8) {
                    val major = i % 4 == 0
                    val y = inset + height * i / 8
                    drawLine(if (major) colors.muted else colors.rule, Offset(x - (if (major) 14.dp else 8.dp).toPx(), y), Offset(x, y), 1.dp.toPx())
                }
                val y = inset + height * (1f - progress)
                drawLine(colors.accent, Offset(x - 16.dp.toPx(), y), Offset(x + 3.dp.toPx(), y), 3.dp.toPx())
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun DurationRow(cfg: Config, add: () -> Unit, remove: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().bottomRule(folio.rule).horizontalScroll(rememberScrollState()).padding(vertical = 3.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        for (m in cfg.durations.distinct().sorted()) {
            val active = m == cfg.minutes
            val shape = RoundedCornerShape(3.dp)
            Box(Modifier.heightIn(min = 48.dp).combinedClickable(role = Role.Button, onClick = { cfg.minutes = m; cfg.save() },
                onLongClickLabel = "Remove duration", onLongClick = { remove(m) }).semantics { selected = active },
                contentAlignment = Alignment.Center) {
                Box(Modifier.widthIn(min = 48.dp).background(if (active) folio.tint else folio.soft, shape)
                    .then(if (active) Modifier.border(1.dp, folio.accent, shape) else Modifier).padding(horizontal = 12.dp, vertical = 7.dp),
                    contentAlignment = Alignment.Center) {
                    T(formatChip(m), 14, if (active) folio.accent else folio.muted)
                }
            }
        }
        Box(Modifier.size(48.dp).clickable(role = Role.Button, onClick = add).semantics { contentDescription = "Custom duration" },
            contentAlignment = Alignment.Center) {
            Box(Modifier.size(34.dp).background(folio.soft, RoundedCornerShape(3.dp)), contentAlignment = Alignment.Center) {
                Ico("plus", folio.muted, 17.dp)
            }
        }
    }
}

@Composable
private fun Tabs(tab: Int, apps: Int, sites: Int, onTab: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().bottomRule(folio.rule).horizontalScroll(rememberScrollState()).selectableGroup(),
        horizontalArrangement = Arrangement.spacedBy(20.dp)) {
        listOf("Applications" to apps, "Websites" to sites).forEachIndexed { i, (name, count) ->
            val active = i == tab
            Row(Modifier.selectable(active, role = Role.Tab) { onTab(i) }
                .then(if (active) Modifier.bottomRule(folio.accent, 2.dp) else Modifier).heightIn(min = 48.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                T(name, 15, if (active) folio.ink else folio.muted, weight = FontWeight.Medium)
                Box(Modifier.background(folio.soft, RoundedCornerShape(3.dp)).padding(horizontal = 5.dp, vertical = 2.dp)) {
                    T(count.toString(), 11, folio.muted, tnum = true)
                }
            }
        }
    }
}

@Composable
private fun AppIcon(pkg: String, size: Dp) {
    val ctx = LocalContext.current
    val bmp = remember(pkg) { Apps.icon(ctx, pkg) }
    if (bmp != null) Image(bmp, null, Modifier.size(size)) else Ico("app-window", folio.muted, size)
}

@Composable
private fun RowLine(label: String, icon: @Composable () -> Unit, detail: String? = null, locked: Boolean, allowed: Boolean = false, onRemove: () -> Unit) {
    Row(Modifier.fillMaxWidth().bottomRule(folio.rule.copy(alpha = .6f)).heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        icon()
        Column(Modifier.weight(1f).padding(vertical = 6.dp)) {
            T(label, 15)
            detail?.let { T(it, 12, folio.muted) }
        }
        if (locked) {
            Box(Modifier.size(48.dp), contentAlignment = Alignment.Center) { Ico(if (allowed) "check" else "lock", folio.muted, 15.dp) }
        } else IconBtn("x", "Remove $label", onClick = onRemove)
    }
}

@Composable
private fun Help(text: String) = T(text, 14, folio.muted, Modifier.padding(vertical = 12.dp))

@Composable
private fun AddRow(text: String, click: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = click).heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        Ico("plus", folio.accent, 17.dp)
        T(text, 14, folio.accent, weight = FontWeight.Medium)
    }
}

@Composable
private fun WebModes(current: String, set: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 9.dp, bottom = 4.dp).border(1.dp, folio.rule, RoundedCornerShape(4.dp)).padding(3.dp).selectableGroup()) {
        for ((mode, label) in listOf("off" to "Off", "allow" to "Allow Only", "block" to "Block List")) {
            val active = current == mode
            Box(Modifier.weight(1f).clip(RoundedCornerShape(3.dp)).background(if (active) folio.tint else Color.Transparent)
                .selectable(active, role = Role.RadioButton) { set(mode) }.heightIn(min = 44.dp).padding(vertical = 4.dp),
                contentAlignment = Alignment.Center) {
                T(label, 13, if (active) folio.accent else folio.muted, weight = FontWeight.Medium)
            }
        }
    }
}

@Composable
private fun EntryDialog(duration: Boolean, allow: Boolean, close: () -> Unit, save: (String) -> String?) {
    var input by rememberSaveable { mutableStateOf("") }
    var error by rememberSaveable { mutableStateOf<String?>(null) }
    val focus = remember { FocusRequester() }
    val title = if (duration) "Custom duration" else if (allow) "Allow a website" else "Block a website"
    val field = if (duration) "Session length" else "Website name or domain"
    Dialog(onDismissRequest = close) {
        val shape = RoundedCornerShape(4.dp)
        Column(Modifier.widthIn(max = 460.dp).fillMaxWidth().background(folio.paper, shape).border(1.dp, folio.rule, shape)
            .verticalScroll(rememberScrollState()).padding(20.dp)) {
            T(title, 26, family = FontFamily.Serif, tracking = (-.6).sp)
            T(field, 14, modifier = Modifier.padding(top = 13.dp, bottom = 6.dp), weight = FontWeight.SemiBold)
            BasicTextField(input, { input = it; error = null },
                Modifier.fillMaxWidth().border(1.dp, folio.rule, shape).focusRequester(focus)
                    .semantics { contentDescription = field }.padding(12.dp), singleLine = true,
                textStyle = TextStyle(color = folio.ink, fontSize = 16.sp), cursorBrush = SolidColor(folio.accent),
                keyboardOptions = KeyboardOptions(keyboardType = if (duration) KeyboardType.Text else KeyboardType.Uri, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { error = save(input) }),
                decorationBox = { inner ->
                    Box {
                        if (input.isEmpty()) T(if (duration) "45 or 1h30" else "youtube or example.com", 15, folio.muted)
                        inner()
                    }
                })
            error?.let { T(it, 13, folio.error, Modifier.padding(top = 7.dp)) }
            Row(Modifier.fillMaxWidth().padding(top = 15.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SecondaryButton("Cancel", Modifier.weight(.9f), onClick = close)
                PrimaryButton(if (duration) "Set duration" else "Add website", Modifier.weight(1.2f)) { error = save(input) }
            }
        }
        LaunchedEffect(Unit) { focus.requestFocus() }
    }
}

/** "Add Applications": every app with a launcher icon, searchable, tap to select several. */
@Composable
private fun Picker(cfg: Config, close: () -> Unit) {
    val ctx = LocalContext.current
    var all by remember { mutableStateOf<List<AppEntry>?>(null) }
    var query by remember { mutableStateOf("") }
    val picked = remember { mutableStateListOf<String>() }
    BackHandler(onBack = close)
    LaunchedEffect(Unit) {
        val have = cfg.apps.toSet()
        all = withContext(Dispatchers.IO) { Apps.launchable(ctx).filter { it.pkg !in have } }
    }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().height(56.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.padding(end = 4.dp)) { IconBtn("arrow-left", "Back", folio.ink, 20.dp, close) }
            T("Add applications", 23, family = FontFamily.Serif)
        }
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(4.dp)).background(folio.soft).border(1.dp, folio.rule, RoundedCornerShape(4.dp))
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Ico("search", folio.muted, 18.dp)
            BasicTextField(
                query, { query = it },
                Modifier.weight(1f).semantics { contentDescription = "Search applications" }.padding(start = 10.dp, top = 13.dp, bottom = 13.dp),
                singleLine = true,
                textStyle = TextStyle(color = folio.ink, fontSize = 15.sp),
                cursorBrush = SolidColor(folio.ink),
                decorationBox = { inner ->
                    Box {
                        if (query.isEmpty()) T("Search your applications", 15, folio.muted, maxLines = 1)
                        inner()
                    }
                },
            )
        }
        Box(Modifier.weight(1f).fillMaxWidth().padding(top = 8.dp)) {
            val list = all
            if (list == null) {
                T("Loading applications…", 15, folio.muted, Modifier.padding(vertical = 14.dp))
            } else {
                val q = query.trim().lowercase()
                val shown = if (q.isEmpty()) list else list.filter { q in it.label.lowercase() || q in it.pkg }
                LazyColumn(Modifier.fillMaxSize()) {
                    items(shown, key = { it.pkg }) { e ->
                        val sel = e.pkg in picked
                        Row(
                            Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(4.dp))
                                .background(if (sel) folio.tint else Color.Transparent)
                                .selectable(sel, role = Role.Checkbox) { if (sel) picked.remove(e.pkg) else picked.add(e.pkg) }
                                .padding(horizontal = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            AppIcon(e.pkg, 32.dp)
                            T(e.label, 16, modifier = Modifier.weight(1f).padding(start = 14.dp), maxLines = 1)
                            if (sel) Ico("check", folio.accent, 20.dp)
                        }
                    }
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(top = 10.dp, bottom = 14.dp)) {
            Spacer(Modifier.weight(1f))
            PrimaryButton(if (picked.isEmpty()) "Add" else "Add ${picked.size}", enabled = picked.isNotEmpty()) {
                cfg.apps = cfg.apps + picked.filter { it !in cfg.apps }
                cfg.save()
                close()
            }
        }
    }
}
