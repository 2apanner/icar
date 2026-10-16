package com.dpilot.icar

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object AppTheme {
    val Canvas = Color(0xFF0A0A0C)
    val Surface = Color(0xFF141416)
    val SurfaceElevated = Color(0xFF1E1E22)
    val SurfaceBorder = Color(0xFF28282E)
    
    val TextPrimary = Color(0xFFF5F5F7)
    val TextSecondary = Color(0xFF8E8E93)
    val TextMuted = Color(0xFF636366)
    
    val Accent = Color(0xFF0A84FF)
    val AccentSubtle = Color(0x260A84FF)
    
    val Nominal = Color(0xFF30D158)
    val Warning = Color(0xFFFF9F0A)
    val Critical = Color(0xFFFF453A)
}

private val DarkColorScheme = darkColorScheme(
    primary = AppTheme.Accent,
    background = AppTheme.Canvas,
    surface = AppTheme.Surface,
    onPrimary = Color.White,
    onBackground = AppTheme.TextPrimary,
    onSurface = AppTheme.TextPrimary
)

@Composable
fun ICARTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
