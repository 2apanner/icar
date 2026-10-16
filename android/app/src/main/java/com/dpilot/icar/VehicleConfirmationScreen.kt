package com.dpilot.icar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

@Composable
fun VehicleConfirmationScreen(
    profile: VehicleProfile,
    onConfirm: () -> Unit,
    onDisconnect: () -> Unit
) {
    var isSyncing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(AppTheme.Canvas)
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(12.dp))

            // Navigation Top Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "VEHICLE VERIFICATION",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = AppTheme.TextMuted
                )

                TextButton(onClick = onDisconnect) {
                    Text("Disconnect", color = AppTheme.TextMuted, fontSize = 12.sp)
                }
            }

            // Connection Link Established Badge
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Nominal.copy(alpha = 0.12f), RoundedCornerShape(10.dp))
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .background(AppTheme.Nominal, CircleShape)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "ECU LINK ESTABLISHED · ISO 15765-4 CAN",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = AppTheme.Nominal
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = "500 kbps",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = AppTheme.TextMuted
                )
            }
        }

        // Vehicle Profile Card
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(16.dp))
                    .border(1.dp, AppTheme.SurfaceBorder, RoundedCornerShape(16.dp))
                    .padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(68.dp)
                        .background(AppTheme.SurfaceElevated, RoundedCornerShape(16.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.DirectionsCar,
                        contentDescription = "Car",
                        tint = AppTheme.Accent,
                        modifier = Modifier.size(32.dp)
                    )
                }

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "${profile.year} ${profile.make} ${profile.model}",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppTheme.TextPrimary
                    )
                    Text(
                        text = profile.engine,
                        fontSize = 13.sp,
                        color = AppTheme.TextSecondary
                    )
                }

                // Verified VIN Badge
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "VEHICLE IDENTIFICATION NUMBER (VIN)",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = AppTheme.TextMuted
                    )

                    Row(
                        modifier = Modifier
                            .background(AppTheme.Canvas, RoundedCornerShape(8.dp))
                            .border(1.dp, AppTheme.SurfaceBorder, RoundedCornerShape(8.dp))
                            .padding(horizontal = 14.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = profile.vin,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace,
                            color = AppTheme.Accent,
                            letterSpacing = 1.2.sp
                        )
                        Icon(
                            imageVector = Icons.Default.CheckCircle,
                            contentDescription = "Verified",
                            tint = AppTheme.Nominal,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }

                Divider(color = AppTheme.SurfaceBorder)

                // Specs Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    SpecColumn(label = "RESTING VOLTAGE", value = "${profile.restingVoltage} V", color = AppTheme.Nominal)
                    SpecColumn(label = "COMMUNICATION", value = "CAN 11/500", color = AppTheme.TextPrimary)
                    SpecColumn(label = "DATABASE SYNC", value = "Supabase", color = AppTheme.Accent)
                }
            }
        }

        // Supabase Cloud Sync Card
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(14.dp))
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Storage,
                            contentDescription = null,
                            tint = AppTheme.Accent,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = "CLOUD TELEMATICS BACKEND",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace,
                            color = AppTheme.TextSecondary
                        )
                    }

                    Text(
                        text = "PostgreSQL",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = AppTheme.TextMuted,
                        modifier = Modifier
                            .background(AppTheme.SurfaceElevated, RoundedCornerShape(4.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }

                Text(
                    text = "This vehicle's VIN and specification record will be registered in your Supabase backend database, enabling fleet monitoring and history tracking from your web app.",
                    fontSize = 12.sp,
                    color = AppTheme.TextSecondary,
                    lineHeight = 17.sp
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = AppTheme.Nominal,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = "Table: public.vehicles · Ready for upsert",
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace,
                        color = AppTheme.TextPrimary
                    )
                }
            }
        }

        // Confirm Action Button
        item {
            Button(
                onClick = {
                    isSyncing = true
                    scope.launch {
                        SupabaseManager.syncVehicleProfile(profile)
                        isSyncing = false
                        onConfirm()
                    }
                },
                enabled = !isSyncing,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
                colors = ButtonDefaults.buttonColors(containerColor = AppTheme.Accent),
                shape = RoundedCornerShape(12.dp)
            ) {
                if (isSyncing) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.width(8.dp))
                    Text("Registering VIN in Supabase...", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color.White)
                } else {
                    Text("Confirm Vehicle & Proceed", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
                    Spacer(Modifier.width(8.dp))
                    Icon(Icons.Default.ArrowForward, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
                }
            }

            Spacer(Modifier.height(4.dp))
            Text(
                text = "Tap confirm to lock vehicle identity and proceed to diagnostic scanning.",
                fontSize = 11.sp,
                color = AppTheme.TextMuted,
                modifier = Modifier.fillMaxWidth(),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SpecColumn(label: String, value: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
        Text(value, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = color)
    }
}
