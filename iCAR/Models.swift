import Foundation

enum TransportKind: String, CaseIterable, Identifiable {
    case bluetooth = "Bluetooth BLE"
    case wifi = "Wi-Fi TCP"
    case demo = "Demo Car"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        case .wifi: return "wifi"
        case .demo: return "car.side.fill"
        }
    }
}

struct DiscoveredAdapter: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: TransportKind
    let detail: String
    let rssi: Int // -30 to -90 dBm
    let isRecommended: Bool
}

struct VehicleProfile {
    var vin: String
    var year: Int
    var make: String
    var model: String
    var engine: String
    var protocolName: String
    var restingVoltage: Double
    
    var maskedVIN: String {
        guard vin.count >= 10 else { return vin }
        let prefix = vin.prefix(3)
        let suffix = vin.suffix(3)
        return "\(prefix)******\(suffix)"
    }
}

enum DTCSeverity: String {
    case nominal = "Nominal"
    case warning = "Caution"
    case critical = "Critical"
}

struct DiagnosticCode: Identifiable {
    let id: String // e.g. P0171
    let title: String
    let system: String // Powertrain, Chassis, Body, Network
    let status: String // Stored, Pending, Permanent
    let severity: DTCSeverity
    let saeDescription: String
    let freezeFrame: [String: String]
    var isPermanent: Bool { status == "Permanent" }
    var driveCycleResolution: String? = nil
    var commonCauses: [String] = []
}

struct ECUErrorEntry: Identifiable {
    let id: String
    let code: String
    let name: String
    let system: String
    var errors: [DiagnosticCode]
    var errorCount: Int { errors.count }
}

struct ServiceResetItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    var statusText: String
    var isDue: Bool
}

struct LiveTelemetryPoint {
    var timestamp: Date
    var rpm: Double
    var speedKmh: Double
    var boostPsi: Double
    var coolantTempC: Double
    var oilTempC: Double
    var batteryVoltage: Double
    var intakeAirTempC: Double
    var stftBank1Percent: Double
    var mafGps: Double
    var throttlePercent: Double
    var currentGear: Int
    var batterySOC: Int // 0-100%
}

struct FlightLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let direction: Direction
    let message: String
    
    enum Direction {
        case tx
        case rx
        case system
    }
}

struct SmogMonitorItem: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isReady: Bool
    let isSupported: Bool
}

struct ECUDeepInfo {
    var calibrationId: String = "Not Reported by ECU"
    var calibrationVerificationNumber: String = "Not Reported by ECU"
    var ecuName: String = "Not Reported by ECU"
    var distanceWithMILKm: Double? = nil
    var distanceSinceDTCClearedKm: Double? = nil
    var warmupsSinceDTCCleared: Int? = nil
    var engineRunTimeSeconds: Int? = nil
    var controlModuleVoltage: Double? = nil
    var smogMonitors: [SmogMonitorItem] = []
    var isMILActive: Bool = false
    var dtcCount: Int = 0
}

struct CodingSafetyResult {
    let isSafe: Bool
    let reason: String?
    let isEngineRunning: Bool
    let isLowVoltage: Bool
    let currentVoltage: Double
    let currentRpm: Double
}

struct VehicleCodingItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let moduleName: String
    let icon: String
    let options: [String]
    var currentValue: String
    let factoryDefaultValue: String
    let isToggle: Bool
}

