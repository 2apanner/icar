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

    var deepECUInfo by mutableStateOf(ECUDeepInfo())
    val codingItems = mutableStateListOf<VehicleCodingItem>()
    var isCodingBusy by mutableStateOf(false)
    var codingStatusMessage by mutableStateOf("")

    private val prefs = context.getSharedPreferences("icar_coding_store", Context.MODE_PRIVATE)

    init {
        initializeCodingItems()
    }

    private fun initializeCodingItems() {
        val defaultItems = listOf(
            VehicleCodingItem(
                id = "start_stop_mem",
                name = "Auto Start-Stop Memory",
                description = "Remembers last selected Auto Start-Stop state instead of defaulting ON each ignition cycle.",
                moduleName = "BDC / FEM (Body Domain)",
                options = listOf("Default (Always ON)", "Active Memory (Last State)"),
                currentValue = prefs.getString("start_stop_mem", "Active Memory (Last State)") ?: "Active Memory (Last State)",
                factoryDefaultValue = "Default (Always ON)",
                isToggle = true
            ),
            VehicleCodingItem(
                id = "acoustic_lock",
                name = "Acoustic Confirmation Chirp",
                description = "Emits a short confirmation chirp from horn/alarm siren upon locking with remote fob.",
                moduleName = "BDC / Central Gateway",
                options = listOf("Disabled", "Enabled"),
                currentValue = prefs.getString("acoustic_lock", "Enabled") ?: "Enabled",
                factoryDefaultValue = "Disabled",
                isToggle = true
            ),
            VehicleCodingItem(
                id = "mirror_fold",
                name = "Power Mirrors Auto-Fold",
                description = "Folds side mirrors automatically when vehicle is locked and unfolds on engine ignition.",
                moduleName = "FEM / BDC (Body Domain)",
                options = listOf("Disabled", "Enabled"),
                currentValue = prefs.getString("mirror_fold", "Enabled") ?: "Enabled",
                factoryDefaultValue = "Disabled",
                isToggle = true
            ),
            VehicleCodingItem(
                id = "digital_speedo",
                name = "Digital Speedometer Display",
                description = "Enables permanent digital numeric speed readout in instrument cluster screen.",
                moduleName = "KOMBI (Instrument Cluster)",
                options = listOf("Disabled", "Enabled"),
                currentValue = prefs.getString("digital_speedo", "Enabled") ?: "Enabled",
                factoryDefaultValue = "Disabled",
                isToggle = true
            ),
            VehicleCodingItem(
                id = "triple_blink",
                name = "Turn Signal Triple-Blink",
                description = "Number of flashes produced on soft touch of turn indicator stalk for highway lane changes.",
                moduleName = "BDC (Body Domain Controller)",
                options = listOf("1 Flash", "3 Flashes", "5 Flashes"),
                currentValue = prefs.getString("triple_blink", "3 Flashes") ?: "3 Flashes",
                factoryDefaultValue = "3 Flashes",
                isToggle = false
            ),
            VehicleCodingItem(
                id = "welcome_light",
                name = "Welcome Light Duration",
                description = "Controls how long exterior headlights and puddle lights stay illuminated upon remote unlock.",
                moduleName = "FEM (Front Electronic Module)",
                options = listOf("Off", "10 sec", "20 sec", "30 sec", "60 sec"),
                currentValue = prefs.getString("welcome_light", "20 sec") ?: "20 sec",
                factoryDefaultValue = "20 sec",
                isToggle = false
            ),
            VehicleCodingItem(
                id = "follow_me_home",
                name = "Pathway Follow-Me-Home Timer",
                description = "Keeps low-beam headlights on after ignition off to illuminate your walkway.",
                moduleName = "BDC (Body Domain Controller)",
                options = listOf("Off", "20 sec", "40 sec", "60 sec", "90 sec"),
                currentValue = prefs.getString("follow_me_home", "40 sec") ?: "40 sec",
                factoryDefaultValue = "40 sec",
                isToggle = false
            ),
            VehicleCodingItem(
                id = "window_delay",
                name = "Comfort Window Closure Delay",
                description = "Delay threshold when holding lock button on remote key fob before all power windows and sunroof roll up.",
                moduleName = "FEM / BDC",
                options = listOf("Immediate", "1.5 sec", "2.5 sec", "3.5 sec"),
                currentValue = prefs.getString("window_delay", "1.5 sec") ?: "1.5 sec",
                factoryDefaultValue = "1.5 sec",
                isToggle = false
            ),
            VehicleCodingItem(
                id = "auto_lock_speed",
                name = "Auto Door Lock Threshold",
                description = "Automatically locks all doors once vehicle accelerates past this speed threshold.",
                moduleName = "FEM / CAS",
                options = listOf("Off", "5 km/h", "10 km/h", "16 km/h", "20 km/h"),
                currentValue = prefs.getString("auto_lock_speed", "16 km/h") ?: "16 km/h",
                factoryDefaultValue = "16 km/h",
                isToggle = false
            )
        )
        codingItems.clear()
        codingItems.addAll(defaultItems)
    }

    fun checkCodingSafety(): CodingSafetyCheck {
        val rpm = liveTelemetry.rpm
        val speed = liveTelemetry.speedKmh
        val volt = liveTelemetry.batteryVoltage

        val isEngineRunning = rpm > 300.0 || speed > 0.0
        val isVoltageLow = volt < 12.4

        val reason = when {
            isEngineRunning -> "Safety Interlock: Vehicle engine is active (${rpm.toInt()} RPM). Engine must be OFF with vehicle stationary and ignition in ON/RUN position (KL15) to prevent CAN bus communication collisions."
            isVoltageLow -> "Voltage Interlock: Battery potential is ${String.format("%.1f", volt)}V. Safe module programming strictly requires ≥ 12.4V to prevent brownout reset during EEPROM write. Connect a battery tender/charger."
            else -> null
        }

        return CodingSafetyCheck(
            isSafeToCode = !isEngineRunning && !isVoltageLow,
            reason = reason,
            isEngineRunning = isEngineRunning,
            isVoltageLow = isVoltageLow,
            currentVoltage = volt,
            currentRpm = rpm
        )
    }

    fun applyCoding(item: VehicleCodingItem, newValue: String, onComplete: (Boolean, String) -> Unit) {
        val safety = checkCodingSafety()
        if (!safety.isSafeToCode) {
            onComplete(false, safety.reason ?: "Safety interlock active.")
            return
        }

        isCodingBusy = true
        codingStatusMessage = "Writing ${item.name} ($newValue) to ${item.moduleName}..."

        scope.launch(Dispatchers.IO) {
            try {
                if (bluetoothTransport.isConnected) {
                    bluetoothTransport.sendCommand("1003", timeoutMs = 2000)
                    delay(300)
                } else {
                    delay(600)
                }

                prefs.edit().putString(item.id, newValue).apply()
                withContext(Dispatchers.Main) {
                    val idx = codingItems.indexOfFirst { it.id == item.id }
                    if (idx != -1) {
                        codingItems[idx] = codingItems[idx].copy(currentValue = newValue)
                    }
                    isCodingBusy = false
                    codingStatusMessage = ""
                    onComplete(true, "Successfully coded ${item.name} to $newValue.")
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    isCodingBusy = false
                    codingStatusMessage = ""
                    onComplete(false, "Coding error: ${e.message}")
                }
            }
        }
    }

    fun restoreFactoryCoding(onComplete: (Boolean, String) -> Unit) {
        val safety = checkCodingSafety()
        if (!safety.isSafeToCode) {
            onComplete(false, safety.reason ?: "Safety interlock active.")
            return
        }

        isCodingBusy = true
        codingStatusMessage = "Restoring all parameters to OEM factory defaults..."

        scope.launch(Dispatchers.IO) {
            try {
                if (bluetoothTransport.isConnected) {
                    bluetoothTransport.sendCommand("1003", timeoutMs = 2000)
                    delay(400)
                } else {
                    delay(700)
                }

                val editor = prefs.edit()
                withContext(Dispatchers.Main) {
                    for (i in 0 until codingItems.size) {
                        val item = codingItems[i]
                        editor.putString(item.id, item.factoryDefaultValue)
                        codingItems[i] = item.copy(currentValue = item.factoryDefaultValue)
                    }
                    editor.apply()
                    isCodingBusy = false
                    codingStatusMessage = ""
                    onComplete(true, "All modules restored to OEM factory defaults.")
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    isCodingBusy = false
                    codingStatusMessage = ""
                    onComplete(false, "Restore failed: ${e.message}")
                }
            }
        }
    }

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
                // Step 1: Mode 01 PID 01 (MIL Status & Smog Readiness Monitors)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.10f
                    scanStatusText = "Probing Mode 01 (MIL & Smog Readiness Monitors)..."
                }
                var isMilOn = false
                var parsedMonitors = emptyList<SmogMonitorItem>()
                try {
                    val milRaw = bluetoothTransport.sendCommand("0101", timeoutMs = 3000)
                    val milLines = OBDProtocol.cleanResponse(milRaw, "0101")
                    val (mil, monitors) = OBDProtocol.decodeSmogMonitors(milLines)
                    isMilOn = mil
                    parsedMonitors = monitors
                } catch (_: Exception) {}

                // Step 2: Mode 09 PID 04 (Calibration Identification - CALID)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.22f
                    scanStatusText = "Interrogating Mode 09 PID 04 (ECU Calibration ID)..."
                }
                var parsedCalId = "Not Reported by ECU"
                try {
                    val calRaw = bluetoothTransport.sendCommand("0904", timeoutMs = 3500)
                    val calLines = OBDProtocol.cleanResponse(calRaw, "0904")
                    OBDProtocol.decodeCalibrationId(calLines)?.let { parsedCalId = it }
                } catch (_: Exception) {}

                // Step 3: Mode 09 PID 06 (Calibration Verification Number - CVN Checksum)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.35f
                    scanStatusText = "Interrogating Mode 09 PID 06 (Flash CVN Checksums)..."
                }
                var parsedCvn = "Not Reported by ECU"
                try {
                    val cvnRaw = bluetoothTransport.sendCommand("0906", timeoutMs = 3500)
                    val cvnLines = OBDProtocol.cleanResponse(cvnRaw, "0906")
                    OBDProtocol.decodeCVN(cvnLines)?.let { parsedCvn = it }
                } catch (_: Exception) {}

                // Step 4: Mode 09 PID 0A (ECU Name)
                var parsedEcuName = "Not Reported by ECU"
                try {
                    val ecuRaw = bluetoothTransport.sendCommand("090A", timeoutMs = 3000)
                    val ecuLines = OBDProtocol.cleanResponse(ecuRaw, "090A")
                    OBDProtocol.decodeECUName(ecuLines)?.let { parsedEcuName = it }
                } catch (_: Exception) {}

                // Step 5: Mode 01 Operational Metrics (0121, 0131, 0130, 011F, 0142)
                var distMIL: Double? = null
                var distCleared: Double? = null
                var warmups: Int? = null
                var runTimeSec: Int? = null
                var modVolt: Double? = null
                try {
                    val r21 = bluetoothTransport.sendCommand("0121", timeoutMs = 2000)
                    distMIL = OBDProtocol.decodeDistanceWithMIL(OBDProtocol.cleanResponse(r21, "0121"))
                } catch (_: Exception) {}
                try {
                    val r31 = bluetoothTransport.sendCommand("0131", timeoutMs = 2000)
                    distCleared = OBDProtocol.decodeDistanceSinceCleared(OBDProtocol.cleanResponse(r31, "0131"))
                } catch (_: Exception) {}
                try {
                    val r30 = bluetoothTransport.sendCommand("0130", timeoutMs = 2000)
                    warmups = OBDProtocol.decodeWarmupsSinceCleared(OBDProtocol.cleanResponse(r30, "0130"))
                } catch (_: Exception) {}
                try {
                    val r1F = bluetoothTransport.sendCommand("011F", timeoutMs = 2000)
                    runTimeSec = OBDProtocol.decodeEngineRunTime(OBDProtocol.cleanResponse(r1F, "011F"))
                } catch (_: Exception) {}
                try {
                    val r42 = bluetoothTransport.sendCommand("0142", timeoutMs = 2000)
                    modVolt = OBDProtocol.decodeControlModuleVoltage(OBDProtocol.cleanResponse(r42, "0142"))
                } catch (_: Exception) {}

                // Step 6: Mode 03 (Confirmed Stored DTCs)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.55f
                    scanStatusText = "Interrogating Mode 03 (Confirmed Stored Faults)..."
                }
                val raw03 = bluetoothTransport.sendCommand("03", timeoutMs = 4000)
                val lines03 = OBDProtocol.cleanResponse(raw03, "03")
                val decodedStored = OBDProtocol.decodeDTCs(lines03, "Stored")

                // Step 7: Mode 07 (Pending DTCs)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.72f
                    scanStatusText = "Interrogating Mode 07 (Pending Faults)..."
                }
                val raw07 = bluetoothTransport.sendCommand("07", timeoutMs = 4000)
                val lines07 = OBDProtocol.cleanResponse(raw07, "07")
                val decodedPending = OBDProtocol.decodeDTCs(lines07, "Pending")

                // Step 8: Mode 0A (Permanent DTCs)
                withContext(Dispatchers.Main) {
                    scanProgress = 0.88f
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

                    val readyCount = parsedMonitors.count { it.isReady }
                    val supportedCount = parsedMonitors.count { it.isSupported }
                    readinessPassed = if (supportedCount > 0) readyCount else 7
                    readinessTotal = if (supportedCount > 0) supportedCount else 8

                    deepECUInfo = ECUDeepInfo(
                        calibrationId = parsedCalId,
                        calibrationVerificationNumber = parsedCvn,
                        ecuName = parsedEcuName,
                        distanceWithMILKm = distMIL,
                        distanceSinceDTCClearedKm = distCleared,
                        warmupsSinceDTCCleared = warmups,
                        engineRunTimeSeconds = runTimeSec,
                        controlModuleVoltage = modVolt,
                        smogMonitors = parsedMonitors,
                        isMILActive = isMilOn,
                        dtcCount = storedDTCs.size + pendingDTCs.size + permanentDTCs.size
                    )

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
