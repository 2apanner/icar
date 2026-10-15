import Foundation

/// BMW ECU Identifiers and Diagnostic Addressing
/// Defines target CAN arbitration IDs for ISO 15765-2 / UDS addressing across BMW platforms.
enum BMWECUModule: String, CaseIterable, Identifiable {
    case dme = "DME / DDE (Engine)"
    case femBdc = "FEM / BDC (Body Domain)"
    case kombi = "KOMBI (Cluster)"
    case huNbt = "HU_NBT / MGU (iDrive)"
    case ihka = "IHKA (Climate)"
    case acsm = "ACSM (Safety / Airbag)"
    case rem = "REM (Rear Electronic)"
    
    var id: String { rawValue }
    
    var shortName: String {
        switch self {
        case .dme: return "DME"
        case .femBdc: return "FEM/BDC"
        case .kombi: return "KOMBI"
        case .huNbt: return "HU_NBT"
        case .ihka: return "IHKA"
        case .acsm: return "ACSM"
        case .rem: return "REM"
        }
    }
    
    /// Target CAN Header to set via ELM327 `ATSH`
    var txHeaderCAN: String {
        switch self {
        case .dme: return "7E0"     // Engine (ECU 00)
        case .femBdc: return "712"  // FEM / BDC Gateway (ECU 40)
        case .kombi: return "760"   // Instrument Cluster (ECU 60)
        case .huNbt: return "763"   // Head Unit / iDrive (ECU 63)
        case .ihka: return "770"    // Automatic Climate (ECU 70)
        case .acsm: return "745"    // Airbag & Restraints (ECU 01)
        case .rem: return "720"     // Rear Electronics (ECU 20)
        }
    }
    
    /// Expected response CAN header from ECU
    var rxHeaderCAN: String {
        switch self {
        case .dme: return "7E8"
        case .femBdc: return "7F2"
        case .kombi: return "768"
        case .huNbt: return "76B"
        case .ihka: return "778"
        case .acsm: return "74D"
        case .rem: return "728"
        }
    }
    
    var iconName: String {
        switch self {
        case .dme: return "engine.combustion.fill"
        case .femBdc: return "car.side.fill"
        case .kombi: return "gauge.with.needle.fill"
        case .huNbt: return "display"
        case .ihka: return "air.conditioner.horizontal"
        case .acsm: return "shield.lefthalf.filled"
        case .rem: return "light.recessed.3"
        }
    }
}

/// BMW Unified Diagnostic Services (UDS / ISO 14229) Protocol Commands
enum BMWUDSCommand {
    static let enterExtendedDiagnosticSession = "10 03"
    static let readDataByIdentifierPrefix = "22"
    static let writeDataByIdentifierPrefix = "2E"
    static let routineControlPrefix = "31"
    static let ecuResetSoft = "11 03"
    static let testerPresent = "3E 00"
}
