package com.dpilot.icar

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope

class MainActivity : ComponentActivity() {
    private lateinit var obdManager: OBDManager

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { _ ->
        // Permissions handled
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        obdManager = OBDManager(applicationContext, lifecycleScope)
        requestRequiredPermissions()

        setContent {
            ICARTheme {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(AppTheme.Canvas)
                ) {
                    AppNavigation(obd = obdManager)
                }
            }
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        if (permissions.isNotEmpty()) {
            permissionLauncher.launch(permissions.toTypedArray())
        }
    }
}

@Composable
fun AppNavigation(obd: OBDManager) {
    var isVehicleConfirmed by remember { mutableStateOf(false) }
    var showingDiagnosticsHub by remember { mutableStateOf(false) }

    when (val state = obd.connectionState) {
        is ConnectionState.Disconnected,
        is ConnectionState.Connecting,
        is ConnectionState.Error -> {
            isVehicleConfirmed = false
            showingDiagnosticsHub = false
            ConnectionScreen(obd = obd)
        }
        is ConnectionState.Connected -> {
            if (!isVehicleConfirmed) {
                // SCREEN 2: INITIAL CONNECTION & VEHICLE VIN CONFIRMATION
                VehicleConfirmationScreen(
                    profile = state.profile,
                    onConfirm = { isVehicleConfirmed = true },
                    onDisconnect = { obd.disconnect() }
                )
            } else if (!obd.hasCompletedScan && !showingDiagnosticsHub) {
                // SCREEN 3: DASHBOARD (SCAN CAR)
                DashboardScanScreen(
                    profile = state.profile,
                    obd = obd,
                    onScanFinished = { showingDiagnosticsHub = true },
                    onDisconnect = { obd.disconnect() }
                )
            } else {
                // SCREEN 4: DIAGNOSTICS & CAR FUNCTIONS HUB
                DiagnosticsHubScreen(
                    profile = state.profile,
                    obd = obd,
                    onBackToDashboard = { showingDiagnosticsHub = false },
                    onDisconnect = { obd.disconnect() }
                )
            }
        }
    }
}
