package com.dpilot.icar

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun DiagnosticsHubScreen(
    profile: VehicleProfile,
    obd: OBDManager,
    onBackToDashboard: () -> Unit,
    onDisconnect: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(0) }
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppTheme.Canvas)
    ) {
        // Top Navigation Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppTheme.Surface)
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Button(
                onClick = onBackToDashboard,
                colors = ButtonDefaults.buttonColors(containerColor = AppTheme.SurfaceElevated),
                shape = RoundedCornerShape(50),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Icon(Icons.Default.ChevronLeft, contentDescription = null, tint = AppTheme.Accent, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text("Dashboard", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppTheme.Accent)
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("${profile.year} ${profile.model}", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
                Text(profile.vin, fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = AppTheme.TextSecondary)
            }

            Button(
                onClick = onDisconnect,
                colors = ButtonDefaults.buttonColors(containerColor = AppTheme.SurfaceElevated),
                shape = RoundedCornerShape(50),
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text("Disconnect", fontSize = 11.sp, color = AppTheme.TextMuted)
            }
        }

        // Sub-tabs Row
        TabRow(
            selectedTabIndex = selectedTab,
            containerColor = AppTheme.SurfaceElevated,
            contentColor = AppTheme.Accent,
            divider = {}
        ) {
            TabItem(title = "Errors", icon = Icons.Default.Warning, isSelected = selectedTab == 0) { selectedTab = 0 }
            TabItem(title = "Sensors", icon = Icons.Default.Speed, isSelected = selectedTab == 1) { selectedTab = 1 }
            TabItem(title = "Battery", icon = Icons.Default.BatteryChargingFull, isSelected = selectedTab == 2) { selectedTab = 2 }
            TabItem(title = "Service", icon = Icons.Default.Build, isSelected = selectedTab == 3) { selectedTab = 3 }
        }

        // Tab Content
        Box(modifier = Modifier.weight(1f).padding(16.dp)) {
            when (selectedTab) {
                0 -> ErrorsTab(obd = obd, profile = profile) {
                    val report = obd.generateReportText(profile)
                    val sendIntent = Intent().apply {
                        action = Intent.ACTION_SEND
                        putExtra(Intent.EXTRA_TEXT, report)
                        type = "text/plain"
                    }
                    context.startActivity(Intent.createChooser(sendIntent, "Share Diagnostic Report"))
                }
                1 -> SensorsTab(obd = obd)
                2 -> BatteryTab(obd = obd, profile = profile)
                3 -> ServiceTab(obd = obd)
            }
        }
    }
}

@Composable
private fun TabItem(title: String, icon: ImageVector, isSelected: Boolean, onClick: () -> Unit) {
    Tab(
        selected = isSelected,
        onClick = onClick,
        text = {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(icon, contentDescription = null, tint = if (isSelected) AppTheme.Accent else AppTheme.TextMuted, modifier = Modifier.size(18.dp))
                Text(title, fontSize = 10.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal, color = if (isSelected) AppTheme.Accent else AppTheme.TextMuted)
            }
        }
    )
}

@Composable
private fun ErrorsTab(obd: OBDManager, profile: VehicleProfile, onShare: () -> Unit) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            // Summary Banner
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(12.dp))
                    .padding(14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("ECU FAULT DIAGNOSTICS", fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
                    Text("${obd.storedDTCs.size + obd.permanentDTCs.size} Total Faults Detected", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = AppTheme.Critical)
                }

                Button(
                    onClick = onShare,
                    colors = ButtonDefaults.buttonColors(containerColor = AppTheme.AccentSubtle),
                    shape = RoundedCornerShape(50)
                ) {
                    Icon(Icons.Default.Share, contentDescription = null, tint = AppTheme.Accent, modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Share", color = AppTheme.Accent, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        val allCodes = obd.permanentDTCs + obd.storedDTCs + obd.pendingDTCs
        items(allCodes) { dtc ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(14.dp))
                    .border(1.dp, if (dtc.severity == DTCSeverity.CRITICAL) AppTheme.Critical.copy(alpha = 0.5f) else AppTheme.SurfaceBorder, RoundedCornerShape(14.dp))
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(dtc.id, fontSize = 16.sp, fontWeight = FontWeight.Black, fontFamily = FontFamily.Monospace, color = if (dtc.severity == DTCSeverity.CRITICAL) AppTheme.Critical else AppTheme.Warning)
                    Text(
                        text = dtc.status.uppercase(),
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        modifier = Modifier
                            .background(if (dtc.severity == DTCSeverity.CRITICAL) AppTheme.Critical else AppTheme.Warning, RoundedCornerShape(4.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }

                Text(dtc.title, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
                Text(dtc.saeDescription, fontSize = 11.sp, color = AppTheme.TextSecondary, lineHeight = 15.sp)
            }
        }
    }
}

@Composable
private fun SensorsTab(obd: OBDManager) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            GaugeRow(label = "ENGINE SPEED", value = "750 RPM", status = "Idling")
            GaugeRow(label = "COOLANT TEMP", value = "88 °C", status = "Optimal (85-95°C)")
            GaugeRow(label = "BATTERY VOLTAGE", value = "12.6 V", status = "Normal")
            GaugeRow(label = "CALCULATED LOAD", value = "18 %", status = "Nominal")
        }
    }
}

@Composable
private fun GaugeRow(label: String, value: String, status: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppTheme.Surface, RoundedCornerShape(12.dp))
            .padding(14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            Text(label, fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
            Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
        }
        Text(status, fontSize = 11.sp, color = AppTheme.Nominal)
    }
}

@Composable
private fun BatteryTab(obd: OBDManager, profile: VehicleProfile) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppTheme.Surface, RoundedCornerShape(14.dp))
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text("BATTERY HEALTH & VOLTAGE", fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
            Text("${profile.restingVoltage} V", fontSize = 28.sp, fontWeight = FontWeight.Black, color = AppTheme.Nominal)
            Text("State of Charge: 92% · Healthy · ${obd.registeredBatteryType}", fontSize = 12.sp, color = AppTheme.TextSecondary)
        }
    }
}

@Composable
private fun ServiceTab(obd: OBDManager) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Text("CONDITION BASED SERVICING (CBS)", fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
        }
        items(obd.serviceItems) { item ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(12.dp))
                    .padding(14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(item.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
                Text(item.statusText, fontSize = 12.sp, color = if (item.isDue) AppTheme.Critical else AppTheme.Nominal)
            }
        }
    }
}
