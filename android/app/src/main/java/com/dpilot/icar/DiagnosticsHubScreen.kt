package com.dpilot.icar

import android.content.Intent
import android.widget.Toast
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
import androidx.compose.ui.text.style.TextAlign
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

        // Sub-tabs Scrollable Row
        ScrollableTabRow(
            selectedTabIndex = selectedTab,
            containerColor = AppTheme.SurfaceElevated,
            contentColor = AppTheme.Accent,
            edgePadding = 8.dp,
            divider = {}
        ) {
            TabItem(title = "Errors", icon = Icons.Default.Warning, isSelected = selectedTab == 0) { selectedTab = 0 }
            TabItem(title = "Sensors", icon = Icons.Default.Speed, isSelected = selectedTab == 1) { selectedTab = 1 }
            TabItem(title = "ECU Info", icon = Icons.Default.Info, isSelected = selectedTab == 2) { selectedTab = 2 }
            TabItem(title = "Battery", icon = Icons.Default.BatteryChargingFull, isSelected = selectedTab == 3) { selectedTab = 3 }
            TabItem(title = "Service", icon = Icons.Default.Build, isSelected = selectedTab == 4) { selectedTab = 4 }
            TabItem(title = "Coding", icon = Icons.Default.Settings, isSelected = selectedTab == 5) { selectedTab = 5 }
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
                2 -> ECUInfoTab(obd = obd, profile = profile)
                3 -> BatteryTab(obd = obd, profile = profile)
                4 -> ServiceTab(obd = obd)
                5 -> CodingTab(obd = obd)
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
                Spacer(Modifier.height(2.dp))
                Text(title, fontSize = 10.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal, color = if (isSelected) AppTheme.Accent else AppTheme.TextMuted)
            }
        }
    )
}

@Composable
private fun ErrorsTab(obd: OBDManager, profile: VehicleProfile, onShare: () -> Unit) {
    val totalFaults = obd.storedDTCs.size + obd.permanentDTCs.size + obd.pendingDTCs.size
    val allCodes = obd.permanentDTCs + obd.storedDTCs + obd.pendingDTCs

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
                    Text(
                        text = if (totalFaults == 0) "0 Faults Detected · All Systems Clear" else "$totalFaults Faults Detected",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (totalFaults == 0) AppTheme.Nominal else AppTheme.Critical
                    )
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

        if (totalFaults == 0) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppTheme.Surface, RoundedCornerShape(14.dp))
                        .padding(28.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = AppTheme.Nominal, modifier = Modifier.size(44.dp))
                    Spacer(Modifier.height(10.dp))
                    Text("Zero Fault Codes Stored in ECU", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
                    Spacer(Modifier.height(4.dp))
                    Text("Engine, transmission, chassis, and body controllers report zero active or pending SAE J2012 diagnostic trouble codes.", fontSize = 11.sp, color = AppTheme.TextSecondary, textAlign = TextAlign.Center)
                }
            }
        } else {
            items(allCodes) { dtc ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppTheme.Surface, RoundedCornerShape(12.dp))
                        .border(1.dp, if (dtc.severity == DTCSeverity.CRITICAL) AppTheme.Critical.copy(alpha = 0.3f) else AppTheme.Warning.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
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
}

@Composable
private fun SensorsTab(obd: OBDManager) {
    val t = obd.liveTelemetry
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            GaugeRow(label = "ENGINE SPEED", value = "${t.rpm.toInt()} RPM", status = if (t.rpm > 300) "Running" else "Ignition ON / Engine OFF")
            GaugeRow(label = "VEHICLE SPEED", value = "${t.speedKmh.toInt()} km/h", status = if (t.speedKmh > 0) "In Motion" else "Stationary")
            GaugeRow(label = "COOLANT TEMPERATURE", value = "${t.coolantTempC.toInt()} °C", status = if (t.coolantTempC in 80.0..105.0) "Optimal (80-105°C)" else "Warming Up")
            GaugeRow(label = "BATTERY VOLTAGE", value = "${String.format("%.1f", t.batteryVoltage)} V", status = if (t.batteryVoltage >= 12.4) "Nominal (≥ 12.4V)" else "Low Potential")
            GaugeRow(label = "CALCULATED ENGINE LOAD", value = "${t.engineLoadPct.toInt()} %", status = "Operating Range")
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
private fun ECUInfoTab(obd: OBDManager, profile: VehicleProfile) {
    val info = obd.deepECUInfo
    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            // Header
            Text("ECU HARDWARE & IDENTIFICATION", fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
        }

        // Section 1: ECU Firmware & Cryptographic Checksums
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(14.dp))
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ECUDetailRow("MODULE NAME", info.ecuName)
                Divider(color = AppTheme.SurfaceBorder)
                ECUDetailRow("CALIBRATION ID (CALID)", info.calibrationId)
                Divider(color = AppTheme.SurfaceBorder)
                ECUDetailRow("CVN CHECKSUM", info.calibrationVerificationNumber)
                Divider(color = AppTheme.SurfaceBorder)
                ECUDetailRow("BUS PROTOCOL", profile.protocolName)
            }
        }

        // Section 2: Operational History & Diagnostic Timers
        item {
            Text("DIAGNOSTIC HISTORY & MILEAGE", fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
        }
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(14.dp))
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ECUDetailRow("MIL LAMP STATUS", if (info.isMILActive) "ACTIVE (CHECK ENGINE ON)" else "OFF (NOMINAL)")
                Divider(color = AppTheme.SurfaceBorder)
                ECUDetailRow(
                    "DISTANCE WITH MIL ACTIVE",
                    if (info.distanceWithMILKm != null) "${info.distanceWithMILKm.toInt()} km (${String.format("%.1f", info.distanceWithMILKm * 0.621371)} mi)" else "Not Reported by ECU"
                )
                Divider(color = AppTheme.SurfaceBorder)
                ECUDetailRow(
                    "DISTANCE SINCE CODES CLEARED",
                    if (info.distanceSinceDTCClearedKm != null) "${info.distanceSinceDTCClearedKm.toInt()} km (${String.format("%.1f", info.distanceSinceDTCClearedKm * 0.621371)} mi)" else "Not Reported by ECU"
                )
                Divider(color = AppTheme.SurfaceBorder)
                ECUDetailRow(
                    "WARMUPS SINCE CODES CLEARED",
                    if (info.warmupsSinceDTCCleared != null) "${info.warmupsSinceDTCCleared} warm-up cycles" else "Not Reported by ECU"
                )
                Divider(color = AppTheme.SurfaceBorder)
                ECUDetailRow(
                    "ENGINE RUN TIME",
                    if (info.engineRunTimeSeconds != null) "${info.engineRunTimeSeconds / 60} min ${info.engineRunTimeSeconds % 60} sec" else "Not Reported by ECU"
                )
                Divider(color = AppTheme.SurfaceBorder)
                ECUDetailRow(
                    "ECU INTERNAL POTENTIAL",
                    if (info.controlModuleVoltage != null) "${String.format("%.2f", info.controlModuleVoltage)} V" else "${String.format("%.2f", obd.liveTelemetry.batteryVoltage)} V"
                )
            }
        }

        // Section 3: Smog Readiness Monitors Breakdown
        if (info.smogMonitors.isNotEmpty()) {
            item {
                Text("EMISSIONS / SMOG READINESS MONITORS", fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
            }
            items(info.smogMonitors) { mon ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppTheme.Surface, RoundedCornerShape(10.dp))
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(mon.name, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppTheme.TextPrimary)
                    Text(
                        text = if (!mon.isSupported) "NOT SUPPORTED" else if (mon.isReady) "READY / PASSED" else "INCOMPLETE",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (!mon.isSupported) AppTheme.TextMuted else if (mon.isReady) AppTheme.Nominal else AppTheme.Warning
                    )
                }
            }
        }
    }
}

@Composable
private fun ECUDetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
        Text(value, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace, color = AppTheme.TextPrimary)
    }
}

@Composable
private fun BatteryTab(obd: OBDManager, profile: VehicleProfile) {
    val volt = if (obd.liveTelemetry.batteryVoltage > 0) obd.liveTelemetry.batteryVoltage else profile.restingVoltage
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppTheme.Surface, RoundedCornerShape(14.dp))
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text("BATTERY HEALTH & VOLTAGE", fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
            Text("${String.format("%.1f", volt)} V", fontSize = 28.sp, fontWeight = FontWeight.Black, color = if (volt >= 12.4) AppTheme.Nominal else AppTheme.Warning)
            Text("State of Charge: ${obd.liveTelemetry.batterySOC}% · ${if (volt >= 12.4) "Healthy" else "Charge Recommended"} · ${obd.registeredBatteryType}", fontSize = 12.sp, color = AppTheme.TextSecondary)
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

@Composable
private fun CodingTab(obd: OBDManager) {
    val context = LocalContext.current
    val safety = obd.checkCodingSafety()
    var showRestoreDialog by remember { mutableStateOf(false) }

    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // Safety Interlock Status Card
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(if (safety.isSafeToCode) AppTheme.Surface else AppTheme.Warning.copy(alpha = 0.12f), RoundedCornerShape(14.dp))
                    .border(1.dp, if (safety.isSafeToCode) AppTheme.Nominal.copy(alpha = 0.3f) else AppTheme.Warning, RoundedCornerShape(14.dp))
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(
                        if (safety.isSafeToCode) Icons.Default.CheckCircle else Icons.Default.Warning,
                        contentDescription = null,
                        tint = if (safety.isSafeToCode) AppTheme.Nominal else AppTheme.Warning,
                        modifier = Modifier.size(18.dp)
                    )
                    Text(
                        text = if (safety.isSafeToCode) "SAFE CONFIGURATION ACTIVE · ZERO FLASH RISK" else "SAFETY INTERLOCK ACTIVE",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = if (safety.isSafeToCode) AppTheme.Nominal else AppTheme.Warning
                    )
                }

                Text(
                    text = if (safety.isSafeToCode) {
                        "Battery potential (${String.format("%.1f", safety.currentVoltage)}V ≥ 12.4V) is optimal. Engine is OFF. DME/DDE engine maps and DSC braking controllers are isolated and read-only."
                    } else {
                        safety.reason ?: "Safety interlock prevents writing to vehicle controllers."
                    },
                    fontSize = 11.sp,
                    color = AppTheme.TextSecondary,
                    lineHeight = 15.sp
                )
            }
        }

        // Restore Factory Baseline CTA
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.Surface, RoundedCornerShape(12.dp))
                    .padding(14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("OEM FACTORY RESTORE", fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
                    Text("Revert all comfort settings to factory baseline", fontSize = 12.sp, color = AppTheme.TextSecondary)
                }

                Button(
                    onClick = { showRestoreDialog = true },
                    enabled = safety.isSafeToCode && !obd.isCodingBusy,
                    colors = ButtonDefaults.buttonColors(containerColor = AppTheme.SurfaceElevated),
                    shape = RoundedCornerShape(50)
                ) {
                    Icon(Icons.Default.Restore, contentDescription = null, tint = AppTheme.Accent, modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Restore", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AppTheme.Accent)
                }
            }
        }

        // Busy status indicator
        if (obd.isCodingBusy) {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppTheme.SurfaceElevated, RoundedCornerShape(12.dp))
                        .border(1.dp, AppTheme.Accent.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(16.dp), color = AppTheme.Accent, strokeWidth = 2.dp)
                    Text(obd.codingStatusMessage, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppTheme.Accent)
                }
            }
        }

        // Coding Options List
        item {
            Text("COMFORT & CONVENIENCE MODULES", fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = AppTheme.TextMuted)
        }

        items(obd.codingItems) { item ->
            CodingItemCard(
                item = item,
                isSafeToCode = safety.isSafeToCode && !obd.isCodingBusy,
                onValueChange = { newVal ->
                    obd.applyCoding(item, newVal) { success, msg ->
                        Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                    }
                }
            )
        }
    }

    if (showRestoreDialog) {
        AlertDialog(
            onDismissRequest = { showRestoreDialog = false },
            title = { Text("Restore Factory Defaults?", fontWeight = FontWeight.Bold) },
            text = { Text("This will rewrite all vehicle comfort parameters back to original OEM factory specification. Drivetrain and safety computers are unaffected.") },
            confirmButton = {
                Button(
                    onClick = {
                        showRestoreDialog = false
                        obd.restoreFactoryCoding { success, msg ->
                            Toast.makeText(context, msg, Toast.LENGTH_LONG).show()
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AppTheme.Accent)
                ) {
                    Text("Yes, Restore Baseline")
                }
            },
            dismissButton = {
                TextButton(onClick = { showRestoreDialog = false }) {
                    Text("Cancel", color = AppTheme.TextMuted)
                }
            }
        )
    }
}

@Composable
private fun CodingItemCard(
    item: VehicleCodingItem,
    isSafeToCode: Boolean,
    onValueChange: (String) -> Unit
) {
    var expandedDropdown by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppTheme.Surface, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(item.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = AppTheme.TextPrimary)
                Text(item.moduleName, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace, color = AppTheme.Accent)
            }

            if (item.isToggle) {
                val isChecked = item.currentValue == "Enabled" || item.currentValue.contains("Active") || item.currentValue == "true"
                Switch(
                    checked = isChecked,
                    onCheckedChange = { checked ->
                        val newVal = if (item.options.size == 2) {
                            if (checked) item.options[1] else item.options[0]
                        } else {
                            if (checked) "Enabled" else "Disabled"
                        }
                        onValueChange(newVal)
                    },
                    enabled = isSafeToCode,
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = AppTheme.Accent,
                        uncheckedThumbColor = AppTheme.TextMuted,
                        uncheckedTrackColor = AppTheme.SurfaceElevated
                    )
                )
            } else {
                Box {
                    Button(
                        onClick = { expandedDropdown = true },
                        enabled = isSafeToCode,
                        colors = ButtonDefaults.buttonColors(containerColor = AppTheme.SurfaceElevated),
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        Text(item.currentValue, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AppTheme.Accent)
                        Spacer(Modifier.width(4.dp))
                        Icon(Icons.Default.ArrowDropDown, contentDescription = null, tint = AppTheme.Accent, modifier = Modifier.size(16.dp))
                    }

                    DropdownMenu(
                        expanded = expandedDropdown,
                        onDismissRequest = { expandedDropdown = false }
                    ) {
                        item.options.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(option, fontSize = 13.sp) },
                                onClick = {
                                    expandedDropdown = false
                                    onValueChange(option)
                                }
                            )
                        }
                    }
                }
            }
        }

        Text(item.description, fontSize = 11.sp, color = AppTheme.TextSecondary, lineHeight = 15.sp)
    }
}
