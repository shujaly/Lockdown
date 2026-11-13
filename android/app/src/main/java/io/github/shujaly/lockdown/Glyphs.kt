package io.github.shujaly.lockdown

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Tabler Icons (MIT), outline style: 24x24 with 2 px round strokes. The same set as the Windows app. */
object Glyphs {
    private val paths = mapOf(
        "lock" to "M5 13a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v6a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-6z M11 16a1 1 0 1 0 2 0a1 1 0 0 0 -2 0 M8 11v-4a4 4 0 1 1 8 0v4",
        "x" to "M18 6l-12 12 M6 6l12 12",
        "plus" to "M12 5l0 14 M5 12l14 0",
        "check" to "M5 12l5 5l10 -10",
        "alert-triangle" to "M12 9v4 M10.363 3.591l-8.106 13.534a1.914 1.914 0 0 0 1.636 2.871h16.214a1.914 1.914 0 0 0 1.636 -2.87l-8.106 -13.536a1.914 1.914 0 0 0 -3.274 0z M12 16h.01",
        "arrow-left" to "M5 12l14 0 M5 12l6 6 M5 12l6 -6",
        "search" to "M10 10m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0 M21 21l-6 -6",
        "world" to "M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0 M3.6 9h16.8 M3.6 15h16.8 M11.5 3a17 17 0 0 0 0 18 M12.5 3a17 17 0 0 1 0 18",
        "app-window" to "M3 5m0 2a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v10a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2z M6 8h.01 M9 8h.01",
        "device-gamepad-2" to "M12 5h3.5a5 5 0 0 1 0 10h-5.5l-4.015 4.227a2.3 2.3 0 0 1 -3.923 -2.035l1.634 -8.173a5 5 0 0 1 4.904 -4.019h3.4z M14 15l4.07 4.284a2.3 2.3 0 0 0 3.925 -2.023l-1.6 -8.232 M8 9v2 M7 10h2 M14 10h2",
        "school" to "M22 9l-10 -4l-10 4l10 4l10 -4v6 M6 10.6v5.4a6 3 0 0 0 12 0v-5.4",
        "file-text" to "M14 3v4a1 1 0 0 0 1 1h4 M17 21h-10a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2h7l5 5v11a2 2 0 0 1 -2 2z M9 9l1 0 M9 13l6 0 M9 17l6 0",
        "clock" to "M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0 M12 7v5l3 3",
        "brand-discord" to "M8 12a1 1 0 1 0 2 0a1 1 0 0 0 -2 0 M14 12a1 1 0 1 0 2 0a1 1 0 0 0 -2 0 M15.5 17c0 1 1.5 3 2 3c1.5 0 2.833 -1.667 3.5 -3c.667 -1.667 .5 -5.833 -1.5 -11.5c-1.457 -1.015 -3 -1.34 -4.5 -1.5l-.972 1.923a11.913 11.913 0 0 0 -4.053 0l-.975 -1.923c-1.5 .16 -3.043 .485 -4.5 1.5c-2 5.667 -2.167 9.833 -1.5 11.5c.667 1.333 2 3 3.5 3c.5 0 2 -2 2 -3 M7 16.5c3.5 1 6.5 1 10 0",
        "brand-steam" to "M16.5 5a4.5 4.5 0 1 1 -.653 8.953l-4.347 3.009l0 .038a3 3 0 0 1 -2.824 3l-.176 0a3 3 0 0 1 -2.94 -2.402l-2.56 -1.098v-3.5l3.51 1.755a2.989 2.989 0 0 1 2.834 -.635l2.727 -3.818a4.5 4.5 0 0 1 4.429 -5.302z M15.5 9.5 a1 1 0 1 0 2 0 a1 1 0 1 0 -2 0",
        "brand-spotify" to "M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0 M8 11.973c2.5 -1.473 5.5 -.973 7.5 .527 M9 15c1.5 -1 4 -1 5 .5 M7 9c2 -1 6 -2 10 .5",
        "brand-whatsapp" to "M3 21l1.65 -3.8a9 9 0 1 1 3.4 2.9l-5.05 .9 M9 10a.5 .5 0 0 0 1 0v-1a.5 .5 0 0 0 -1 0v1a5 5 0 0 0 5 5h1a.5 .5 0 0 0 0 -1h-1a.5 .5 0 0 0 0 1",
        "brand-tiktok" to "M21 7.917v4.034a9.948 9.948 0 0 1 -5 -1.951v4.5a6.5 6.5 0 1 1 -8 -6.326v4.326a2.5 2.5 0 1 0 4 2v-11.5h4.083a6.005 6.005 0 0 0 4.917 4.917z",
        "brand-youtube" to "M2 8a4 4 0 0 1 4 -4h12a4 4 0 0 1 4 4v8a4 4 0 0 1 -4 4h-12a4 4 0 0 1 -4 -4v-8z M10 9l5 3l-5 3z",
        "brand-google-drive" to "M12 10l-6 10l-3 -5l6 -10z M9 15h12l-3 5h-12 M15 15l-6 -10h6l6 10z",
        "brand-gmail" to "M16 20h3a1 1 0 0 0 1 -1v-14a1 1 0 0 0 -1 -1h-3v16z M5 20h3v-16h-3a1 1 0 0 0 -1 1v14a1 1 0 0 0 1 1z M16 4l-4 4l-4 -4 M4 6.5l8 7.5l8 -7.5",
        "brand-instagram" to "M4 4m0 4a4 4 0 0 1 4 -4h8a4 4 0 0 1 4 4v8a4 4 0 0 1 -4 4h-8a4 4 0 0 1 -4 -4z M12 12m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0 M16.5 7.5l0 .01",
        "brand-facebook" to "M7 10v4h3v7h4v-7h3l1 -4h-4v-2a1 1 0 0 1 1 -1h3v-4h-3a5 5 0 0 0 -5 5v2h-3",
        "brand-x" to "M4 4l11.733 16h4.267l-11.733 -16z M4 20l6.768 -6.768m2.46 -2.46l6.772 -6.772",
        "brand-reddit" to "M12 8c2.648 0 5.028 .826 6.675 2.14a2.5 2.5 0 0 1 2.326 4.36c0 3.59 -4.03 6.5 -9 6.5c-4.875 0 -8.845 -2.8 -9 -6.294l-1 -.206a2.5 2.5 0 0 1 2.326 -4.36c1.646 -1.313 4.026 -2.14 6.674 -2.14z M12 8l1 -5l6 1 M19 4m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M10 17c.667 .333 1.333 .5 2 .5s1.333 -.167 2 -.5 M8.5 13 a0.5 0.5 0 1 0 1 0 a0.5 0.5 0 1 0 -1 0 M14.5 13 a0.5 0.5 0 1 0 1 0 a0.5 0.5 0 1 0 -1 0",
        "brand-netflix" to "M9 3l10 18h-4l-10 -18z M5 3v18h4v-10.5 M19 21v-18h-4v10.5",
        "brand-twitch" to "M4 5v11a1 1 0 0 0 1 1h2v4l4 -4h5.584c.266 0 .52 -.105 .707 -.293l2.415 -2.414c.187 -.188 .293 -.442 .293 -.708v-8.585a1 1 0 0 0 -1 -1h-14a1 1 0 0 0 -1 1z M16 8l0 4 M12 8l0 4",
        "brand-snapchat" to "M16.882 7.842a4.882 4.882 0 0 0 -9.764 0c0 4.273 -.213 6.409 -4.118 8.118c2 .882 2 .882 3 3c3 0 4 2 6 2s3 -2 6 -2c1 -2.118 1 -2.118 3 -3c-3.906 -1.709 -4.118 -3.845 -4.118 -8.118zm-13.882 8.119c4 -2.118 4 -4.118 1 -7.118m17 7.118c-4 -2.118 -4 -4.118 -1 -7.118",
        "brand-pinterest" to "M8 20l4 -9 M10.7 14c.437 1.263 1.43 2 2.55 2c2.071 0 3.75 -1.554 3.75 -4a5 5 0 1 0 -9.7 1.7 M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0",
        "brand-openai" to "M11.217 19.384a3.501 3.501 0 0 0 6.783 -1.217v-5.167l-6 -3.35 M5.214 15.014a3.501 3.501 0 0 0 4.446 5.266l4.34 -2.534v-6.946 M6 7.63c-1.391 -.236 -2.787 .395 -3.534 1.689a3.474 3.474 0 0 0 1.271 4.745l4.263 2.514l6 -3.348 M12.783 4.616a3.501 3.501 0 0 0 -6.783 1.217v5.067l6 3.45 M18.786 8.986a3.501 3.501 0 0 0 -4.446 -5.266l-4.34 2.534v6.946 M18 16.302c1.391 .236 2.787 -.395 3.534 -1.689a3.474 3.474 0 0 0 -1.271 -4.745l-4.308 -2.514l-5.955 3.42",
    )
    private val cache = HashMap<String, ImageVector>()

    fun get(name: String): ImageVector = cache.getOrPut(name) {
        ImageVector.Builder(name = name, defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 24f, viewportHeight = 24f)
            .addPath(
                pathData = addPathNodes(paths[name] ?: paths.getValue("world")),
                stroke = SolidColor(Color.White),
                strokeLineWidth = 2f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round,
            )
            .build()
    }
}

@Composable
fun Ico(name: String, color: Color, size: Dp, modifier: Modifier = Modifier) {
    Image(rememberVectorPainter(Glyphs.get(name)), contentDescription = null, modifier = modifier.size(size), colorFilter = ColorFilter.tint(color))
}
