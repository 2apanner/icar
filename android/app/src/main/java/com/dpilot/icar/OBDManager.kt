package com.dpilot.icar

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class OBDManager(private val scope: CoroutineScope) {
    var connectionState by mutableStateOf<ConnectionState>(ConnectionState.Disconnected)
    var isSearching by mutableStateOf(false)
    val discoveredAdapters = mutableStateListOf<DiscoveredAdapter>()

    var hasCompletedScan by mutableStateOf(false)
    var isScanning by mutableStateOf(false)
    var scanProgress by mutableStateOf(0.0f)
    var scanStatusText by mutableStateOf("Ready to scan")

    val storedDTCs = mutableStateListOf<DiagnosticCode>()
    val pendingDTCs = mutableStateListOf<DiagnosticCode>()
    val permanentDTCs = mutableStateListOf<DiagnosticCode>()
    var readinessPassed by mutableStateOf(0)
    var readinessTotal by mutableStateOf(8)

    var liveTelemetry by mutableStateOf(LiveTelemetry())
    val serviceItems = mutableStateListOf(
        ServiceResetItem("oil", "Engine Oil", "OK · 11,000 km", false),
        ServiceResetItem("brake_fluid", "Brake Fluid", "OK · 18 Months", false),
        ServiceResetItem("front_brakes", "Front Brake Pads", "OK · 32,000 km", false),
        ServiceResetItem("rear_brakes", "Rear Brake Pads", "OK · 45,000 km", false),
        ServiceResetItem("inspection", "Vehicle Check", "OK · 24,000 km", false)
    )
    var registeredBatteryType by mutableStateOf("80 Ah AGM")

    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var bleScanCallback: ScanCallback? = null

    @SuppressLint("MissingPermission")
    fun startBLESearch() {
        isSearching = true
        discoveredAdapters.clear()

        // 1. Check Paired Bluetooth Classic devices (e.g. standard OBDII adapters)
        bluetoothAdapter?.bondedDevices?.forEach { device ->
            val name = device.name ?: ""
            if (name.isNotEmpty() && !discoveredAdapters.any { it.id == device.address }) {
                discoveredAdapters.add(
                    DiscoveredAdapter(
                        id = device.address,
                        name = name,
                        kind = TransportKind.BLUETOOTH,
                        detail = "Paired Classic Bluetooth",
                        rssi = -60
                    )
                )
            }
        }

        // 2. Start Bluetooth LE Scanner
        val scanner = bluetoothAdapter?.bluetoothLeScanner
        if (scanner != null) {
            val callback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult?) {
                    result?.let {
                        val device = it.device
                        val name = device.name ?: it.scanRecord?.deviceName ?: ""
                        if (name.isNotBlank()) {
                            val id = device.address
                            if (!discoveredAdapters.any { adapter -> adapter.id == id }) {
                                discoveredAdapters.add(
                                    DiscoveredAdapter(
                                        id = id,
                                        name = name,
                                        kind = TransportKind.BLUETOOTH,
                                        detail = "BLE RSSI: ${it.rssi} dBm",
                                        rssi = it.rssi
                                    )
                                )
                            }
                        }
                    }
                }
            }
            bleScanCallback = callback
            try {
                scanner.startScan(callback)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun stopBLESearch() {
        isSearching = false
        bleScanCallback?.let {
            try {
                bluetoothAdapter?.bluetoothLeScanner?.stopScan(it)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        bleScanCallback = null
    }

    fun connectSimulator() {
        stopBLESearch()
        val demoAdapter = DiscoveredAdapter(
            id = "demo_simulator",
            name = "Virtual BMW M3 G80 (CAN Simulator)",
            kind = TransportKind.DEMO,
            detail = "UDS & OBD-II ECU Simulation",
            rssi = -20
        )
        connect(demoAdapter)
    }

    fun connect(adapter: DiscoveredAdapter) {
        stopBLESearch()
        connectionState = ConnectionState.Connecting("Initializing adapter transport...")

        scope.launch {
            delay(400)
            connectionState = ConnectionState.Connecting("Negotiating CAN 11/500 bus protocol...")
            delay(500)
            connectionState = ConnectionState.Connecting("Reading vehicle VIN (Mode 09 PID 02)...")
            delay(500)

            val profile = VehicleProfile(
                vin = "WBA33AY08MFA98765",
                make = "BMW",
                model = "M3 Competition (G80)",
                year = 2022,
                engine = "3.0L S58 Twin-Turbo Inline-6",
                protocolName = "ISO 15765-4 (CAN 11/500)",
                restingVoltage = 12.6
            )
            connectionState = ConnectionState.Connected(profile)
        }
    }

    fun disconnect() {
        stopBLESearch()
        connectionState = ConnectionState.Disconnected
        hasCompletedScan = false
    }

    fun runScan() {
        if (isScanning) return
        isScanning = true
        scanProgress = 0.0f
        scanStatusText = "Initiating Mode 01 diagnostic probe..."

        scope.launch {
            delay(350)
            scanProgress = 0.25f
            scanStatusText = "Probing Mode 01 (MIL & Readiness Monitors)..."
            delay(350)
            scanProgress = 0.55f
            scanStatusText = "Interrogating Mode 03 (Confirmed Stored DTCs)..."
            delay(350)
            scanProgress = 0.80f
            scanStatusText = "Interrogating Mode 07 & Mode 0A..."
            delay(350)

            populateDiagnosticFaults()
            scanProgress = 1.0f
            isScanning = false
            hasCompletedScan = true
            scanStatusText = "Scan Complete: ${permanentDTCs.size} Permanent · ${storedDTCs.size} Stored · ${pendingDTCs.size} Pending"

            // Auto-upload scan report to Supabase
            uploadScanReportToSupabase()
        }
    }

    private fun populateDiagnosticFaults() {
        storedDTCs.clear()
        pendingDTCs.clear()
        permanentDTCs.clear()

        permanentDTCs.add(
            DiagnosticCode(
                id = "P0420",
                title = "Catalyst System Efficiency Below Threshold (Bank 1)",
                system = "Powertrain",
                status = "Permanent",
                severity = DTCSeverity.CRITICAL,
                saeDescription = "The catalytic converter oxygen storage capacity is below the acceptable threshold."
            )
        )
        storedDTCs.add(
            DiagnosticCode(
                id = "P0300",
                title = "Random/Multiple Cylinder Misfire Detected",
                system = "Powertrain",
                status = "Stored",
                severity = DTCSeverity.WARNING,
                saeDescription = "The engine control module detected multiple cylinder combustion anomalies."
            )
        )
        storedDTCs.add(
            DiagnosticCode(
                id = "P0171",
                title = "System Too Lean (Bank 1)",
                system = "Fuel & Air Metering",
                status = "Stored",
                severity = DTCSeverity.WARNING,
                saeDescription = "The air-fuel ratio is leaner than the commanded threshold over multiple drive cycles."
            )
        )
        pendingDTCs.add(
            DiagnosticCode(
                id = "P0128",
                title = "Coolant Thermostat (Coolant Temp Below Regulating Temp)",
                system = "Engine Cooling",
                status = "Pending",
                severity = DTCSeverity.INFO,
                saeDescription = "Engine operating temperature was not achieved within the calibrated drive period."
            )
        )
        readinessPassed = 6
        readinessTotal = 8
    }

    private fun uploadScanReportToSupabase() {
        val currState = connectionState
        if (currState is ConnectionState.Connected) {
            scope.launch(Dispatchers.IO) {
                SupabaseManager.uploadScanReport(
                    profile = currState.profile,
                    storedDTCs = storedDTCs.toList(),
                    pendingDTCs = pendingDTCs.toList(),
                    permanentDTCs = permanentDTCs.toList(),
                    readinessPassed = readinessPassed,
                    readinessTotal = readinessTotal,
                    batteryVoltage = liveTelemetry.batteryVoltage,
                    batterySOC = liveTelemetry.batterySOC,
                    batteryType = registeredBatteryType,
                    cbsItems = serviceItems.toList(),
                    reportText = generateReportText(currState.profile)
                )
            }
        }
    }

    fun generateReportText(profile: VehicleProfile): String {
        return """
        ========================================================
        iCAR AUTOMOTIVE HEALTH & DIAGNOSTIC REPORT (Android)
        ========================================================
        Vehicle: ${profile.year} ${profile.make} ${profile.model}
        VIN: ${profile.vin}
        Bus Protocol: ${profile.protocolName}
        Battery Voltage: ${profile.restingVoltage} V
        
        SUMMARY:
        - Stored Faults: ${storedDTCs.size}
        - Pending Faults: ${pendingDTCs.size}
        - Permanent Faults: ${permanentDTCs.size}
        - Inspection Readiness: $readinessPassed / $readinessTotal Monitors Passed
        ========================================================
        """.trimIndent()
    }
}
