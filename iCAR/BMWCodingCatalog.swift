import Foundation

enum BMWCodingCategory: String, CaseIterable, Identifiable {
    case engineDynamics = "Engine & Dynamics"
    case mirrorsWindows = "Mirrors & Windows"
    case clusterGauges = "Cluster & Gauges"
    case idriveAudio = "iDrive & Audio"
    case lighting = "Lighting & Optics"
    case batteryMaintenance = "Battery & Service"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .engineDynamics: return "bolt.car.fill"
        case .mirrorsWindows: return "car.side.rear.open"
        case .clusterGauges: return "gauge.with.needle.fill"
        case .idriveAudio: return "waveform.badge.magnifyingglass"
        case .lighting: return "lightbulb.led.wide.fill"
        case .batteryMaintenance: return "battery.100.bolt"
        }
    }
}

struct BMWCodingParameter: Identifiable {
    let id: String
    let name: String
    let category: BMWCodingCategory
    let module: BMWECUModule
    let parameterSymbol: String // FDL Coding Symbol
    let didHex: String          // UDS Data Identifier (e.g. 0x3000)
    let bitOffset: Int
    let byteMask: UInt8
    var isEnabled: Bool
    var selectedOption: String
    let options: [String]
    let description: String
    let safetyLevel: SafetyLevel
    
    enum SafetyLevel: String {
        case safe = "Safe"
        case moderate = "Moderate"
        case developer = "Advanced"
    }
}

class BMWCodingCatalog {
    static let shared = BMWCodingCatalog()
    
    var parameters: [BMWCodingParameter] = [
        // Engine & Dynamics
        BMWCodingParameter(
            id: "bmw_start_stop_mem",
            name: "Auto Start-Stop Memory",
            category: .engineDynamics,
            module: .femBdc,
            parameterSymbol: "TC_MSA_MEMORY",
            didHex: "3000",
            bitOffset: 0,
            byteMask: 0x01,
            isEnabled: true,
            selectedOption: "Active",
            options: ["Active", "Not Active"],
            description: "Remembers the last selected Auto Start-Stop state across engine restarts instead of defaulting to ON.",
            safetyLevel: .safe
        ),
        BMWCodingParameter(
            id: "bmw_exhaust_flap",
            name: "Exhaust Flap Override",
            category: .engineDynamics,
            module: .dme,
            parameterSymbol: "EXHAUST_FLAP_MODE",
            didHex: "3100",
            bitOffset: 4,
            byteMask: 0x02,
            isEnabled: false,
            selectedOption: "Automatic",
            options: ["Automatic", "Always Open (Sport Sound)", "Always Closed"],
            description: "Forces the electronically-controlled exhaust muffler valve to stay open for full exhaust acoustics.",
            safetyLevel: .safe
        ),
        
        // Mirrors & Windows
        BMWCodingParameter(
            id: "bmw_mirror_fold",
            name: "Mirrors Auto-Fold on Lock",
            category: .mirrorsWindows,
            module: .femBdc,
            parameterSymbol: "ASP_BEIKLAPPEN_BEI_KOMFORTSCHLIESSEN",
            didHex: "3110",
            bitOffset: 2,
            byteMask: 0x04,
            isEnabled: true,
            selectedOption: "Active",
            options: ["Active", "Not Active"],
            description: "Folds the exterior rear-view mirrors immediately when locking the car with the key fob or Comfort Access.",
            safetyLevel: .safe
        ),
        BMWCodingParameter(
            id: "bmw_curb_mirror_tilt",
            name: "Reverse Curb Mirror Dip Angle",
            category: .mirrorsWindows,
            module: .femBdc,
            parameterSymbol: "ASP_BORDSTEINAUTOMATIK_DELTA",
            didHex: "3110",
            bitOffset: 0,
            byteMask: 0x70,
            isEnabled: true,
            selectedOption: "70%",
            options: ["40%", "50%", "70%", "90%"],
            description: "Adjusts how far the passenger side mirror tilts downward when engaging reverse gear to prevent curb rash.",
            safetyLevel: .safe
        ),
        
        // Cluster & Gauges (KOMBI)
        BMWCodingParameter(
            id: "bmw_digital_speedo",
            name: "Digital Speedometer Display",
            category: .clusterGauges,
            module: .kombi,
            parameterSymbol: "BC_DIGITAL_V",
            didHex: "3000",
            bitOffset: 1,
            byteMask: 0x02,
            isEnabled: true,
            selectedOption: "Active",
            options: ["Active", "Not Active"],
            description: "Enables real-time digital numeric speed in the onboard computer display of the instrument cluster.",
            safetyLevel: .safe
        ),
        BMWCodingParameter(
            id: "bmw_needle_sweep",
            name: "Needle Sweep on Ignition (Staging)",
            category: .clusterGauges,
            module: .kombi,
            parameterSymbol: "STAGING_ENABLE",
            didHex: "3000",
            bitOffset: 6,
            byteMask: 0x40,
            isEnabled: true,
            selectedOption: "Active",
            options: ["Active", "Not Active"],
            description: "Sweeps the tachometer and speedometer needle indicators to maximum and back when turning on ignition.",
            safetyLevel: .safe
        ),
        BMWCodingParameter(
            id: "bmw_cluster_logo",
            name: "Cluster Startup Logo",
            category: .clusterGauges,
            module: .kombi,
            parameterSymbol: "STARTUP_EMBLEM",
            didHex: "3005",
            bitOffset: 0,
            byteMask: 0x0F,
            isEnabled: true,
            selectedOption: "M Performance",
            options: ["Standard BMW", "M Performance", "Alpina", "M2 / M3 / M4"],
            description: "Changes the startup badge displayed in the digital LCD display of the instrument cluster.",
            safetyLevel: .safe
        ),
        
        // iDrive & Audio (HU_NBT)
        BMWCodingParameter(
            id: "bmw_acoustic_chirp",
            name: "Acoustic Lock Confirmation (Chirp)",
            category: .idriveAudio,
            module: .huNbt,
            parameterSymbol: "ACOUSTIC_LOCK_CONFIRM",
            didHex: "3000",
            bitOffset: 3,
            byteMask: 0x08,
            isEnabled: true,
            selectedOption: "Active",
            options: ["Active", "Not Active"],
            description: "Adds the 'Acoustic lock' checkbox to iDrive Settings -> Doors/Keys so the horn/siren beeps on lock.",
            safetyLevel: .safe
        ),
        BMWCodingParameter(
            id: "bmw_warning_chime",
            name: "Vehicle Warning Chime Tone",
            category: .idriveAudio,
            module: .huNbt,
            parameterSymbol: "BRAND_SOUND",
            didHex: "3002",
            bitOffset: 0,
            byteMask: 0x07,
            isEnabled: true,
            selectedOption: "Rolls-Royce",
            options: ["BMW Standard", "Rolls-Royce (Gentle Chime)", "BMW i (Electric)", "Mini"],
            description: "Changes seatbelt, door open, and low fuel gong audio tones to the luxurious Rolls-Royce or BMW i chime.",
            safetyLevel: .safe
        ),
        BMWCodingParameter(
            id: "bmw_rdc_tire_info",
            name: "Tire Temperature & Pressure Display",
            category: .idriveAudio,
            module: .huNbt,
            parameterSymbol: "RDC_DRUCK_TEMP",
            didHex: "3001",
            bitOffset: 2,
            byteMask: 0x04,
            isEnabled: true,
            selectedOption: "Pressure & Temperature",
            options: ["Pressure Only", "Pressure & Temperature"],
            description: "Shows live tire temperature in degrees alongside PSI for all four wheels in the iDrive Vehicle Status screen.",
            safetyLevel: .safe
        ),
        BMWCodingParameter(
            id: "bmw_video_in_motion",
            name: "Video in Motion (VIM)",
            category: .idriveAudio,
            module: .huNbt,
            parameterSymbol: "SPEEDLOCK_X_KMH_MIN",
            didHex: "3000",
            bitOffset: 0,
            byteMask: 0xFF,
            isEnabled: false,
            selectedOption: "Disabled",
            options: ["Disabled (Standard)", "Enabled Unlimited"],
            description: "Allows USB video playback and screen mirroring to continue while the vehicle is driving.",
            safetyLevel: .moderate
        ),
        
        // Lighting
        BMWCodingParameter(
            id: "bmw_ambient_color",
            name: "Ambient Lighting Color Scheme",
            category: .lighting,
            module: .femBdc,
            parameterSymbol: "AMBIENT_LIGHTING_COLOR",
            didHex: "3070",
            bitOffset: 0,
            byteMask: 0x0F,
            isEnabled: true,
            selectedOption: "Champagne / Bronze",
            options: ["Classic Orange", "Modern White", "Champagne / Bronze", "Blue / Cyan", "Lilac / Purple"],
            description: "Recalibrates RGB LEDs in cabin door cards and dash to custom luxury color themes.",
            safetyLevel: .safe
        ),
        
        // Battery & Service (BMS)
        BMWCodingParameter(
            id: "bmw_bms_capacity",
            name: "BMS Battery Capacity & Type",
            category: .batteryMaintenance,
            module: .dme,
            parameterSymbol: "BATTERIE_KAPAZITAET",
            didHex: "3020",
            bitOffset: 0,
            byteMask: 0x0F,
            isEnabled: true,
            selectedOption: "70Ah AGM",
            options: ["70Ah AGM", "80Ah AGM", "90Ah AGM", "105Ah AGM", "70Ah EFB"],
            description: "Programs DME alternator charging algorithm for newly installed battery chemistry and Amp-hour capacity.",
            safetyLevel: .safe
        )
    ]
}
