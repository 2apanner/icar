package com.dpilot.icar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun DashboardScanScreen(
    profile: VehicleProfile,
    obd: OBDManager,
    onScanFinished: () -> Unit,
    onDisconnect: () -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(AppTheme.Canvas)
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(10.dp))

            // Vehicle Top Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.SurfaceElevated, RoundedCornerShape(12.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(modifier = Modifier.size(8.dp).background(AppTheme.Nominal, CircleShape))
                    Column {
                        Text("${profile.year} ${profile.model}", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
                        Text(profile.vin, fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = AppTheme.Accent)
                    }
                }

                TextButton(onClick = onDisconnect) {
                    Text("Disconnect", color = AppTheme.TextMuted, fontSize = 11.sp)
                }
            }
        }

        // Action Hero Card: SCAN CAR
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(20.dp))
                    .border(1.dp, AppTheme.SurfaceBorder, RoundedCornerShape(20.dp))
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .background(AppTheme.SurfaceElevated, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.DirectionsCar,
                        contentDescription = null,
                        tint = AppTheme.Accent,
                        modifier = Modifier.size(40.dp)
                    )
                }

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Ready for Health Scan", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
                    Text("Interrogates all powertrain, chassis & body modules", fontSize = 12.sp, color = AppTheme.TextSecondary)
                }

                if (obd.isScanning) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        LinearProgressIndicator(
                            progress = obd.scanProgress,
                            modifier = Modifier.fillMaxWidth().height(8.dp),
                            color = AppTheme.Accent,
                            trackColor = AppTheme.SurfaceElevated
                        )
                        Text(obd.scanStatusText, fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = AppTheme.TextSecondary)
                    }
                } else {
                    Button(
                        onClick = {
                            obd.runScan()
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(56.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = AppTheme.Accent),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Icon(Icons.Default.Bolt, contentDescription = null, tint = Color.White)
                        Spacer(Modifier.width(8.dp))
                        Text("SCAN CAR", fontSize = 18.sp, fontWeight = FontWeight.Black, color = Color.White, letterSpacing = 1.sp)
                    }
                }

                if (obd.hasCompletedScan) {
                    Button(
                        onClick = onScanFinished,
                        modifier = Modifier.fillMaxWidth().height(48.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = AppTheme.Nominal),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("View Diagnostic Report & Car Functions", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color.White)
                    }
                }
            }
        }

        // Quick Stats Card
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(16.dp))
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                StatItem(label = "BATTERY", value = "${profile.restingVoltage}V", status = "Good")
                StatItem(label = "BUS PROTOCOL", value = "CAN 11/500", status = "Locked")
                StatItem(label = "CLOUD SYNC", value = "Supabase", status = "Connected")
            }
        }
    }
}

@Composable
private fun StatItem(label: String, value: String, status: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
        Text(value, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
        Text(status, fontSize = 10.sp, color = AppTheme.Nominal)
    }
}
