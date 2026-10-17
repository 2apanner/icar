package com.dpilot.icar

enum class TransportKind {
    BLUETOOTH,
    WIFI,
    DEMO
}

data class DiscoveredAdapter(
    val id: String,
    val name: String,
    val kind: TransportKind,
    val detail: String,
    val rssi: Int
)

data class VehicleProfile(
    val vin: String,
    val make: String,
    val model: String,
    val year: Int,
    val engine: String,
    val protocolName: String,
    val restingVoltage: Double
)

enum class DTCSeverity {
    INFO,
    WARNING,
    CRITICAL
}

data class DiagnosticCode(
    val id: String,
    val title: String,
    val system: String,
    val status: String,
    val severity: DTCSeverity,
    val saeDescription: String,
    val freezeFrame: Map<String, String> = emptyMap(),
    val commonCauses: List<String> = emptyList(),
    val driveCycleResolution: String? = null
)

data class ServiceResetItem(
    val id: String,
    val name: String,
    val statusText: String,
    val isDue: Boolean
)

data class LiveTelemetry(
    val rpm: Double = 0.0,
    val speedKmh: Double = 0.0,
    val coolantTempC: Double = 0.0,
    val batteryVoltage: Double = 12.6,
    val batterySOC: Int = 92,
    val engineLoadPct: Double = 0.0
)

sealed class ConnectionState {
    object Disconnected : ConnectionState()
    data class Connecting(val step: String) : ConnectionState()
    data class Connected(val profile: VehicleProfile) : ConnectionState()
    data class Error(val message: String) : ConnectionState()
}

data class SmogMonitorItem(
    val name: String,
    val isReady: Boolean,
    val isSupported: Boolean
)

data class ECUDeepInfo(
    val calibrationId: String = "Not Reported by ECU",
    val calibrationVerificationNumber: String = "Not Reported by ECU",
    val ecuName: String = "Not Reported by ECU",
    val distanceWithMILKm: Double? = null,
    val distanceSinceDTCClearedKm: Double? = null,
    val warmupsSinceDTCCleared: Int? = null,
    val engineRunTimeSeconds: Int? = null,
    val controlModuleVoltage: Double? = null,
    val smogMonitors: List<SmogMonitorItem> = emptyList(),
    val isMILActive: Boolean = false,
    val dtcCount: Int = 0
)

data class VehicleCodingItem(
    val id: String,
    val name: String,
    val description: String,
    val moduleName: String,
    val options: List<String>,
    val currentValue: String,
    val factoryDefaultValue: String,
    val isToggle: Boolean = false
)

data class CodingSafetyCheck(
    val isSafeToCode: Boolean,
    val reason: String?,
    val isEngineRunning: Boolean,
    val isVoltageLow: Boolean,
    val currentVoltage: Double,
    val currentRpm: Double
)

