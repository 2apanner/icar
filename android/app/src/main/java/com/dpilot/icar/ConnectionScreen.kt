package com.dpilot.icar

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bluetooth
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun ConnectionScreen(obd: OBDManager) {
    val infiniteTransition = rememberInfiniteTransition(label = "radar")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.4f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "pulseScale"
    )

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(AppTheme.Canvas)
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(24.dp))

            // Brand Header
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(76.dp)
                        .background(AppTheme.SurfaceElevated, shape = RoundedCornerShape(18.dp))
                        .border(1.dp, AppTheme.SurfaceBorder, RoundedCornerShape(18.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.DirectionsCar,
                        contentDescription = "iCAR Logo",
                        tint = AppTheme.Accent,
                        modifier = Modifier.size(36.dp)
                    )
                }

                Text(
                    text = "iCAR",
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Black,
                    color = AppTheme.TextPrimary,
                    letterSpacing = 1.5.sp
                )

                Text(
                    text = "Intelligent Connected Automotive Reader",
                    fontSize = 13.sp,
                    color = AppTheme.TextSecondary
                )

                Row(
                    modifier = Modifier
                        .background(AppTheme.SurfaceElevated, shape = RoundedCornerShape(6.dp))
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .background(AppTheme.Nominal, CircleShape)
                    )
                    Text(
                        text = "BLUETOOTH LE & CLASSIC · CLOUD TELEMATICS",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = AppTheme.TextMuted
                    )
                }
            }
        }

        // Connection Action Area
        if (!obd.isSearching && obd.discoveredAdapters.isEmpty()) {
            item {
                // Primary Search Hero Button
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            brush = Brush.horizontalGradient(
                                listOf(AppTheme.Accent, Color(0xFF144EA0))
                            ),
                            shape = RoundedCornerShape(18.dp)
                        )
                        .clickable { obd.startBLESearch() }
                        .padding(18.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .background(Color.White.copy(alpha = 0.2f), CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Bluetooth,
                                contentDescription = "Bluetooth",
                                tint = Color.White,
                                modifier = Modifier.size(24.dp)
                            )
                        }

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Search & Connect OBD-II",
                                fontSize = 17.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                            Text(
                                text = "Scan for nearby Bluetooth adapters",
                                fontSize = 12.sp,
                                color = Color.White.copy(alpha = 0.85f)
                            )
                        }

                        Icon(
                            imageVector = Icons.Default.ChevronRight,
                            contentDescription = "Go",
                            tint = Color.White.copy(alpha = 0.8f)
                        )
                    }
                }
            }

            // Setup Steps Card
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppTheme.Surface, RoundedCornerShape(16.dp))
                        .border(1.dp, AppTheme.SurfaceBorder, RoundedCornerShape(16.dp))
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        text = "HOW TO CONNECT",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = AppTheme.TextMuted
                    )

                    SetupStep(num = "1", title = "Plug in Adapter", detail = "Connect your OBD adapter to the 16-pin port under the driver dashboard.")
                    SetupStep(num = "2", title = "Ignition ON", detail = "Switch vehicle ignition ON (engine OFF or running).")
                    SetupStep(num = "3", title = "Tap Search", detail = "Press Search above to pair and read vehicle VIN.")
                }
            }


        } else {
            // Actively Searching / Discovered State
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppTheme.Surface, RoundedCornerShape(18.dp))
                        .border(1.dp, AppTheme.SurfaceBorder, RoundedCornerShape(18.dp))
                        .padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Box(
                            modifier = Modifier
                                .size(76.dp)
                                .scale(pulseScale)
                                .border(2.dp, AppTheme.Accent.copy(alpha = 0.3f), CircleShape)
                        )
                        Box(
                            modifier = Modifier
                                .size(56.dp)
                                .background(AppTheme.AccentSubtle, CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Bluetooth,
                                contentDescription = "Scanning",
                                tint = AppTheme.Accent,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }

                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = if (obd.isSearching) "Searching for OBD-II Devices..." else "Discovered Devices",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = AppTheme.TextPrimary
                        )
                        Text(
                            text = if (obd.isSearching) "Listening for nearby Bluetooth adapters" else "Select your adapter to connect",
                            fontSize = 12.sp,
                            color = AppTheme.TextSecondary
                        )
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        if (obd.isSearching) {
                            Button(
                                onClick = { obd.stopBLESearch() },
                                colors = ButtonDefaults.buttonColors(containerColor = AppTheme.Critical.copy(alpha = 0.15f))
                            ) {
                                Text("Stop Search", color = AppTheme.Critical, fontSize = 12.sp)
                            }
                        } else {
                            Button(
                                onClick = { obd.startBLESearch() },
                                colors = ButtonDefaults.buttonColors(containerColor = AppTheme.SurfaceElevated)
                            ) {
                                Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(14.dp), tint = AppTheme.Accent)
                                Spacer(Modifier.width(6.dp))
                                Text("Scan Again", color = AppTheme.Accent, fontSize = 12.sp)
                            }
                        }
                    }
                }
            }

            // Discovered Adapters List
            if (obd.discoveredAdapters.isNotEmpty()) {
                item {
                    Text(
                        text = "DISCOVERED BLUETOOTH DEVICES",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = AppTheme.TextMuted,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                items(obd.discoveredAdapters) { adapter ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(AppTheme.Surface, RoundedCornerShape(14.dp))
                            .border(1.dp, AppTheme.Accent.copy(alpha = 0.4f), RoundedCornerShape(14.dp))
                            .clickable { obd.connect(adapter) }
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(44.dp)
                                .background(AppTheme.AccentSubtle, RoundedCornerShape(12.dp)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Bluetooth,
                                contentDescription = null,
                                tint = AppTheme.Accent,
                                modifier = Modifier.size(20.dp)
                            )
                        }

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = adapter.name,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = AppTheme.TextPrimary
                            )
                            Text(
                                text = "Signal: ${adapter.rssi} dBm · ${adapter.detail}",
                                fontSize = 11.sp,
                                fontFamily = FontFamily.Monospace,
                                color = AppTheme.TextSecondary
                            )
                        }

                        Button(
                            onClick = { obd.connect(adapter) },
                            colors = ButtonDefaults.buttonColors(containerColor = AppTheme.Accent),
                            shape = RoundedCornerShape(50)
                        ) {
                            Text("Connect", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color.White)
                        }
                    }
                }
            } else if (obd.isSearching) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        CircularProgressView(color = AppTheme.Accent)
                        Text(
                            text = "Listening for nearby Bluetooth devices...",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            color = AppTheme.TextSecondary
                        )
                        Text(
                            text = "Make sure your Bluetooth adapter is plugged in and powered on.",
                            fontSize = 11.sp,
                            color = AppTheme.TextMuted
                        )
                    }
                }
            }
        }

        // Connecting Modal
        if (obd.connectionState is ConnectionState.Connecting) {
            val step = (obd.connectionState as ConnectionState.Connecting).step
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppTheme.SurfaceElevated, RoundedCornerShape(16.dp))
                        .border(1.dp, AppTheme.Accent.copy(alpha = 0.4f), RoundedCornerShape(16.dp))
                        .padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    CircularProgressView(color = AppTheme.Accent)
                    Text("Connecting to Vehicle", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
                    Text(step, fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = AppTheme.TextSecondary)
                    TextButton(onClick = { obd.disconnect() }) {
                        Text("Cancel", fontSize = 12.sp, color = AppTheme.TextMuted)
                    }
                }
            }
        }
        // Connection Error Card
        if (obd.connectionState is ConnectionState.Error) {
            val errMsg = (obd.connectionState as ConnectionState.Error).message
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppTheme.SurfaceElevated, RoundedCornerShape(16.dp))
                        .border(1.dp, AppTheme.Critical.copy(alpha = 0.6f), RoundedCornerShape(16.dp))
                        .padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Warning,
                        contentDescription = "Error",
                        tint = AppTheme.Critical,
                        modifier = Modifier.size(32.dp)
                    )
                    Text("Connection Failed", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = AppTheme.Critical)
                    Text(errMsg, fontSize = 12.sp, color = AppTheme.TextSecondary, textAlign = TextAlign.Center)
                    Button(
                        onClick = { obd.disconnect(); obd.startBLESearch() },
                        colors = ButtonDefaults.buttonColors(containerColor = AppTheme.Critical.copy(alpha = 0.2f))
                    ) {
                        Text("Dismiss & Search Again", color = AppTheme.Critical, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(30.dp))
        }
    }
}

@Composable
private fun SetupStep(num: String, title: String, detail: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .background(AppTheme.SurfaceElevated, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(num, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppTheme.Accent)
        }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppTheme.TextPrimary)
            Text(detail, fontSize = 11.sp, color = AppTheme.TextSecondary, lineHeight = 16.sp)
        }
    }
}

@Composable
private fun CircularProgressView(color: Color) {
    CircularProgressIndicator(
        modifier = Modifier.size(28.dp),
        color = color,
        strokeWidth = 3.dp
    )
}
