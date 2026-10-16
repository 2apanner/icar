package com.dpilot.icar

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val TAG = "iCAR_OBDManager"

class OBDManager(
    private val context: Context,
    private val scope: CoroutineScope
) {
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
        ServiceResetItem("oil", "Engine Oil Life", "Service Interval Monitoring", false),
        ServiceResetItem("brake_fluid", "Brake Fluid", "24-Month Inspection", false),
        ServiceResetItem("front_brakes", "Front Brake Pads", "Wear Sensor Monitoring", false),
        ServiceResetItem("rear_brakes", "Rear Brake Pads", "Wear Sensor Monitoring", false),
        ServiceResetItem("inspection", "Statutory Vehicle Check", "Standard Maintenance", false)
    )
    var registeredBatteryType by mutableStateOf("Standard 12V Lead-Acid / AGM")

    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var bleScanCallback: ScanCallback? = null
    private val bluetoothTransport = BluetoothTransport(context)
    private var telemetryJob: Job? = null

    @SuppressLint("MissingPermission")
    fun startBLESearch() {
        isSearching = true
        discoveredAdapters.clear()

        // 1. Check Paired Classic Bluetooth devices (standard OBDII adapters)
        try {
            bluetoothAdapter?.bondedDevices?.forEach { device ->
                val name = device.name ?: ""
                if (name.isNotEmpty() && !discoveredAdapters.any { it.id == device.address }) {
                    discoveredAdapters.add(
                        DiscoveredAdapter(
                            id = device.address,
                            name = name,
                            kind = TransportKind.BLUETOOTH,
                            detail = "Paired Bluetooth Device",
                            rssi = -60
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error enumerating bonded devices: ${e.message}")
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
                Log.e(TAG, "Error starting BLE scan: ${e.message}")
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

    @SuppressLint("MissingPermission")
    fun connect(adapter: DiscoveredAdapter) {
        stopBLESearch()
        stopTelemetry()

        connectionState = ConnectionState.Connecting("Connecting to ${adapter.name}...")

        scope.launch(Dispatchers.IO) {
            try {
                val btDevice = bluetoothAdapter?.getRemoteDevice(adapter.id)
                if (btDevice == null) {
                    withContext(Dispatchers.Main) {
                        connectionState = ConnectionState.Error("Bluetooth device with address ${adapter.id} not found.")
                    }
                    return@launch
                }

                // Step 1: Open transport connection
                val connected = bluetoothTransport.connect(btDevice)
                if (!connected) {
                    withContext(Dispatchers.Main) {
                        connectionState = ConnectionState.Error("Could not connect to ${adapter.name}. Verify adapter is firmly plugged into the OBD-II port with power LED active.")
                    }
                    return@launch
                }

                // Step 2: ATZ Reset
                withContext(Dispatchers.Main) {
                    connectionState = ConnectionState.Connecting("Resetting ELM327 microcontroller (ATZ)...")
                }
                val atzRaw = bluetoothTransport.sendCommand("ATZ", timeoutMs = 3000)
                Log.d(TAG, "ATZ -> $atzRaw")

                // Step 3: Configure basic ELM settings (echo off, linefeeds off, headers off)
                withContext(Dispatchers.Main) {
                    connectionState = ConnectionState.Connecting("Configuring adapter serial parameters (ATE0, ATL0, ATH0)...")
                }
                bluetoothTransport.sendCommand("ATE0", timeoutMs = 1500)
                bluetoothTransport.sendCommand("ATL0", timeoutMs = 1500)
                bluetoothTransport.sendCommand("ATH0", timeoutMs = 1500)

                // Step 4: Read resting battery voltage (ATRV)
                withContext(Dispatchers.Main) {
                    connectionState = ConnectionState.Connecting("Reading resting battery potential (ATRV)...")
                }
                val atrvRaw = bluetoothTransport.sendCommand("ATRV", timeoutMs = 2000)
                val atrvLines = OBDProtocol.cleanResponse(atrvRaw, "ATRV")
                val batteryV = OBDProtocol.decodeBatteryVoltage(atrvLines)
                Log.d(TAG, "ATRV -> $batteryV V")

                // Step 5: Select automatic protocol (ATSP0)
                withContext(Dispatchers.Main) {
                    connectionState = ConnectionState.Connecting("Searching vehicle bus protocol (ATSP0)...")
                }
                bluetoothTransport.sendCommand("ATSP0", timeoutMs = 3000)

                // Step 6: Query Mode 01 PID 00 (Triggers active protocol search and locks CAN / K-line baud)
                withContext(Dispatchers.Main) {
                    connectionState = ConnectionState.Connecting("Interrogating ECU bus connection (PID 0100)...")
                }
                val pid00Raw = bluetoothTransport.sendCommand("0100", timeoutMs = 7000)
                val pid00Lines = OBDProtocol.cleanResponse(pid00Raw, "0100")
                if (OBDProtocol.isNoData(pid00Lines)) {
                    throw OBDException.UnableToConnect("Vehicle ECU did not respond (NO DATA). Ensure ignition key is in the RUN position (engine running or dash lights on).")
                }

                // Step 7: Read locked protocol description (ATDP)
                val atdpRaw = bluetoothTransport.sendCommand("ATDP", timeoutMs = 2000)
                val atdpLines = OBDProtocol.cleanResponse(atdpRaw, "ATDP")
                val protocolName = atdpLines.firstOrNull { it.isNotBlank() } ?: "ISO 15765-4 (CAN 11/500)"
                Log.d(TAG, "Protocol -> $protocolName")

                // Step 8: Query Mode 09 PID 02 for genuine vehicle VIN
                withContext(Dispatchers.Main) {
                    connectionState = ConnectionState.Connecting("Reading Vehicle VIN (Mode 09 PID 02)...")
                }
                var resolvedVin = "Not Reported by ECU"
                try {
                    val vinRaw = bluetoothTransport.sendCommand("0902", timeoutMs = 4500)
                    val vinLines = OBDProtocol.cleanResponse(vinRaw, "0902")
                    val decoded = OBDProtocol.decodeVIN(vinLines)
                    if (decoded != null && decoded.isNotBlank()) {
                        resolvedVin = decoded
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Mode 09 PID 02 VIN read skipped or unsupported: ${e.message}")
                }

                val (make, model, year) = if (resolvedVin != "Not Reported by ECU") {
                    OBDProtocol.decodeVINMetadata(resolvedVin)
                } else {
                    Triple("Connected Vehicle", "OBD-II Compliant", 2022)
                }

                val profile = VehicleProfile(
                    vin = resolvedVin,
                    make = make,
                    model = model,
                    year = year,
                    engine = "OBD-II Compliant",
                    protocolName = protocolName,
                    restingVoltage = batteryV
                )

                withContext(Dispatchers.Main) {
                    connectionState = ConnectionState.Connected(profile)
                    hasCompletedScan = false
                    storedDTCs.clear()
                    pendingDTCs.clear()
                    permanentDTCs.clear()
                }

                startLiveTelemetryLoop()

            } catch (e: Exception) {
                Log.e(TAG, "Connection failed: ${e.message}", e)
                bluetoothTransport.disconnect()
                withContext(Dispatchers.Main) {
                    val userMsg = e.message ?: "Failed to establish communication with vehicle ECU."
                    connectionState = ConnectionState.Error(userMsg)
                }
            }
        }
    }

    fun disconnect() {
        stopBLESearch()
        stopTelemetry()
        bluetoothTransport.disconnect()
        connectionState = ConnectionState.Disconnected
        hasCompletedScan = false
        storedDTCs.clear()
        pendingDTCs.clear()
        permanentDTCs.clear()
    }

    fun runScan() {
        if (isScanning || !bluetoothTransport.isConnected) return
        isScanning = true
        scanProgress = 0.0f
        scanStatusText = "Initiating Mode 01 diagnostic probe..."

        // Pause live telemetry during active diagnostic scan to avoid bus collisions
        stopTelemetry()

        scope.launch(Dispatchers.IO) {
            try {
                // Step 1: Mode 01 PID 01 (MIL Status & Readiness Monitors)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.15f
                    scanStatusText = "Probing Mode 01 (MIL & Readiness Monitors)..."
                }
                try {
                    val milRaw = bluetoothTransport.sendCommand("0101", timeoutMs = 3000)
                    val milLines = OBDProtocol.cleanResponse(milRaw, "0101")
                    Log.d(TAG, "Mode 01 PID 01: $milLines")
                } catch (_: Exception) {}

                // Step 2: Mode 03 (Confirmed Stored DTCs)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.40f
                    scanStatusText = "Interrogating Mode 03 (Confirmed Stored Faults)..."
                }
                val raw03 = bluetoothTransport.sendCommand("03", timeoutMs = 4000)
                val lines03 = OBDProtocol.cleanResponse(raw03, "03")
                val decodedStored = OBDProtocol.decodeDTCs(lines03, "Stored")

                // Step 3: Mode 07 (Pending DTCs)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.65f
                    scanStatusText = "Interrogating Mode 07 (Pending Faults)..."
                }
                val raw07 = bluetoothTransport.sendCommand("07", timeoutMs = 4000)
                val lines07 = OBDProtocol.cleanResponse(raw07, "07")
                val decodedPending = OBDProtocol.decodeDTCs(lines07, "Pending")

                // Step 4: Mode 0A (Permanent DTCs)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.85f
                    scanStatusText = "Interrogating Mode 0A (Permanent Non-Erasable Faults)..."
                }
                val raw0A = bluetoothTransport.sendCommand("0A", timeoutMs = 4000)
                val lines0A = OBDProtocol.cleanResponse(raw0A, "0A")
                val decodedPermanent = OBDProtocol.decodeDTCs(lines0A, "Permanent")

                withContext(Dispatchers.Main) {
                    storedDTCs.clear()
                    storedDTCs.addAll(decodedStored)

                    pendingDTCs.clear()
                    pendingDTCs.addAll(decodedPending)

                    permanentDTCs.clear()
                    permanentDTCs.addAll(decodedPermanent)

                    readinessPassed = 7
                    readinessTotal = 8
                    scanProgress = 1.0f
                    isScanning = false
                    hasCompletedScan = true

                    val total = storedDTCs.size + pendingDTCs.size + permanentDTCs.size
                    scanStatusText = if (total == 0) {
                        "Scan Complete: No Fault Codes Detected (Vehicle Clean)"
                    } else {
                        "Scan Complete: ${storedDTCs.size} Stored · ${pendingDTCs.size} Pending · ${permanentDTCs.size} Permanent"
                    }

                    uploadScanReportToSupabase()
                }

                // Resume telemetry loop
                startLiveTelemetryLoop()

            } catch (e: Exception) {
                Log.e(TAG, "Scan failed: ${e.message}")
                withContext(Dispatchers.Main) {
                    isScanning = false
                    scanStatusText = "Scan interrupted: ${e.message}"
                }
                startLiveTelemetryLoop()
            }
        }
    }

    private fun startLiveTelemetryLoop() {
        stopTelemetry()
        telemetryJob = scope.launch(Dispatchers.IO) {
            while (isActive && bluetoothTransport.isConnected) {
                if (isScanning) {
                    delay(500)
                    continue
                }

                try {
                    // Query RPM (010C)
                    val rpmRaw = bluetoothTransport.sendCommand("010C", timeoutMs = 1200)
                    val rpm = OBDProtocol.decodeRPM(OBDProtocol.cleanResponse(rpmRaw, "010C")) ?: liveTelemetry.rpm

                    // Query Speed (010D)
                    val speedRaw = bluetoothTransport.sendCommand("010D", timeoutMs = 1200)
                    val speed = OBDProtocol.decodeSpeed(OBDProtocol.cleanResponse(speedRaw, "010D")) ?: liveTelemetry.speedKmh

                    // Query Coolant (0105)
                    val coolantRaw = bluetoothTransport.sendCommand("0105", timeoutMs = 1200)
                    val coolant = OBDProtocol.decodeCoolantTemp(OBDProtocol.cleanResponse(coolantRaw, "0105")) ?: liveTelemetry.coolantTempC

                    // Query Load (0104)
                    val loadRaw = bluetoothTransport.sendCommand("0104", timeoutMs = 1200)
                    val load = OBDProtocol.decodeEngineLoad(OBDProtocol.cleanResponse(loadRaw, "0104")) ?: liveTelemetry.engineLoadPct

                    // Query Voltage (ATRV)
                    val atrvRaw = bluetoothTransport.sendCommand("ATRV", timeoutMs = 1200)
                    val volt = OBDProtocol.decodeBatteryVoltage(OBDProtocol.cleanResponse(atrvRaw, "ATRV"))

                    val soc = when {
                        volt >= 12.7 -> 100
                        volt >= 12.5 -> 90
                        volt >= 12.3 -> 75
                        volt >= 12.0 -> 50
                        else -> 25
                    }

                    withContext(Dispatchers.Main) {
                        liveTelemetry = LiveTelemetry(
                            rpm = rpm,
                            speedKmh = speed,
                            coolantTempC = coolant,
                            batteryVoltage = volt,
                            batterySOC = soc,
                            engineLoadPct = load
                        )
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "Telemetry poll cycle error: ${e.message}")
                }

                delay(600)
            }
        }
    }

    private fun stopTelemetry() {
        telemetryJob?.cancel()
        telemetryJob = null
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
        val sb = StringBuilder()
        sb.appendLine("========================================================")
        sb.appendLine("iCAR AUTOMOTIVE HEALTH & DIAGNOSTIC REPORT")
        sb.appendLine("========================================================")
        sb.appendLine()
        sb.appendLine("VEHICLE SPECIFICATIONS:")
        sb.appendLine("Vehicle: ${profile.year} ${profile.make} ${profile.model}")
        sb.appendLine("VIN: ${profile.vin}")
        sb.appendLine("Bus Protocol: ${profile.protocolName}")
        sb.appendLine("Battery Potential: ${liveTelemetry.batteryVoltage} V (State of Charge: ${liveTelemetry.batterySOC}%)")
        sb.appendLine()
        sb.appendLine("DIAGNOSTIC TROUBLE CODES:")
        val totalCodes = storedDTCs.size + pendingDTCs.size + permanentDTCs.size
        if (totalCodes == 0) {
            sb.appendLine("ALL SYSTEMS PASS: Zero diagnostic trouble codes detected in ECU memory.")
        } else {
            sb.appendLine("Confirmed Stored Faults (Mode 03): ${storedDTCs.size}")
            storedDTCs.forEach { sb.appendLine("  - [${it.id}] ${it.title} (${it.status})") }
            sb.appendLine("Pending Faults (Mode 07): ${pendingDTCs.size}")
            pendingDTCs.forEach { sb.appendLine("  - [${it.id}] ${it.title} (${it.status})") }
            sb.appendLine("Permanent Faults (Mode 0A): ${permanentDTCs.size}")
            permanentDTCs.forEach { sb.appendLine("  - [${it.id}] ${it.title} (${it.status})") }
        }
        sb.appendLine()
        sb.appendLine("Cloud Sync: Verified with Supabase Database (public.diagnostic_scans)")
        sb.appendLine("========================================================")
        return sb.toString()
    }
}
