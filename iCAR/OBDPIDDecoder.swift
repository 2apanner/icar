import Foundation

/// SAE J1979 / SAE J2012 Automotive Protocol Decoding Engine
/// Computes physical engineering units from raw ECU binary payloads.
enum OBDPIDDecoder {
    
    // MARK: - Supported PID Bitmask Decoder (Mode 01 PID 00, 20, 40)
    static func parseSupportedPIDs(bytes: [UInt8], basePid: UInt8) -> Set<UInt8> {
        var supported = Set<UInt8>()
        guard bytes.count >= 4 else { return supported }
        
        let mask = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        
        for bitIndex in 0..<32 {
            let pid = basePid + UInt8(bitIndex + 1)
            let isSet = (mask & (1 << (31 - bitIndex))) != 0
            if isSet {
                supported.insert(pid)
            }
        }
        return supported
    }
    
    // MARK: - Mode 01 Live Sensor Formulas
    static func decodeRPM(bytes: [UInt8]) -> Double? {
        // PID 0C: ((A * 256) + B) / 4.0
        guard bytes.count >= 2 else { return nil }
        let a = Double(bytes[0])
        let b = Double(bytes[1])
        return ((a * 256.0) + b) / 4.0
    }
    
    static func decodeSpeedKmh(bytes: [UInt8]) -> Double? {
        // PID 0D: A
        guard let a = bytes.first else { return nil }
        return Double(a)
    }
    
    static func decodeCoolantTempC(bytes: [UInt8]) -> Double? {
        // PID 05: A - 40
        guard let a = bytes.first else { return nil }
        return Double(a) - 40.0
    }
    
    static func decodeIntakeAirTempC(bytes: [UInt8]) -> Double? {
        // PID 0F: A - 40
        guard let a = bytes.first else { return nil }
        return Double(a) - 40.0
    }
    
    static func decodeManifoldPressureKpa(bytes: [UInt8]) -> Double? {
        // PID 0B: A
        guard let a = bytes.first else { return nil }
        return Double(a)
    }
    
    static func decodeBoostPsi(mapKpa: Double, baroKpa: Double = 101.3) -> Double {
        let gaugeKpa = mapKpa - baroKpa
        return gaugeKpa * 0.145038 // kPa to PSI
    }
    
    static func decodeMassAirFlowGps(bytes: [UInt8]) -> Double? {
        // PID 10: ((A * 256) + B) / 100.0
        guard bytes.count >= 2 else { return nil }
        let a = Double(bytes[0])
        let b = Double(bytes[1])
        return ((a * 256.0) + b) / 100.0
    }
    
    static func decodeThrottlePercent(bytes: [UInt8]) -> Double? {
        // PID 11: (A * 100.0) / 255.0
        guard let a = bytes.first else { return nil }
        return (Double(a) * 100.0) / 255.0
    }
    
    static func decodeEngineLoadPercent(bytes: [UInt8]) -> Double? {
        // PID 04: (A * 100.0) / 255.0
        guard let a = bytes.first else { return nil }
        return (Double(a) * 100.0) / 255.0
    }
    
    static func decodeFuelTrimPercent(bytes: [UInt8]) -> Double? {
        // PID 06 (STFT) & PID 07 (LTFT): ((A - 128) * 100.0) / 128.0
        guard let a = bytes.first else { return nil }
        return ((Double(a) - 128.0) * 100.0) / 128.0
    }
    
    static func decodeTimingAdvanceDegrees(bytes: [UInt8]) -> Double? {
        // PID 0E: (A / 2.0) - 64.0
        guard let a = bytes.first else { return nil }
        return (Double(a) / 2.0) - 64.0
    }
    
    // MARK: - SAE J2012 Diagnostic Trouble Code (DTC) Decoder
    // Mode 03 (Stored), Mode 07 (Pending), Mode 0A (Permanent)
    static func decodeDTCs(payload: [UInt8]) -> [String] {
        var codes: [String] = []
        var raw = payload
        
        // If odd number of bytes, first byte is typically DTC count (e.g. 01 01 71)
        if raw.count % 2 != 0 {
            raw = Array(raw.dropFirst())
        }
        
        var i = 0
        // Mode 03 / 07 / 0A response payload consists of consecutive 2-byte pairs
        // e.g. [0x01, 0x71] -> "P0171"
        while i + 1 < raw.count {
            let byte1 = raw[i]
            let byte2 = raw[i + 1]
            i += 2
            
            // 0x00 0x00 indicates padding / end of list
            if byte1 == 0 && byte2 == 0 {
                continue
            }
            
            let systemLetter: String
            switch (byte1 & 0xC0) >> 6 {
            case 0b00: systemLetter = "P" // Powertrain
            case 0b01: systemLetter = "C" // Chassis
            case 0b10: systemLetter = "B" // Body
            case 0b11: systemLetter = "U" // Network
            default: systemLetter = "P"
            }
            
            let standardType = (byte1 & 0x30) >> 4
            let digit2 = String(format: "%X", standardType)
            let digit3 = String(format: "%X", byte1 & 0x0F)
            let digit45 = String(format: "%02X", byte2)
            
            let dtc = "\(systemLetter)\(digit2)\(digit3)\(digit45)"
            codes.append(dtc)
        }
        
        return codes
    }
    
    // MARK: - SAE J2012 DTC Technical Knowledge Base
    struct DTCKnowledge {
        let title: String
        let system: String
        let severity: DTCSeverity
        let saeDescription: String
        let commonCauses: [String]
        let driveCycleResolution: String?
    }
    
    static func lookupDTCInfo(code: String, status: String) -> DTCKnowledge {
        let isPerm = (status == "Permanent")
        
        switch code.uppercased() {
        case "P0420":
            return DTCKnowledge(
                title: "Catalyst System Efficiency Below Threshold (Bank 1)",
                system: "Powertrain",
                severity: .critical,
                saeDescription: "The ECM continuously monitors catalytic converter oxygen storage capability via pre-cat and post-cat O2 sensors. Catalyst efficiency has dropped below the minimum emissions threshold. Permanent DTCs are retained in non-volatile EEPROM and CANNOT be erased by OBD scan tools.",
                commonCauses: [
                    "Degraded or melted internal catalytic converter substrate",
                    "Exhaust leak before or within 10 inches of catalytic converter",
                    "Defective downstream heated oxygen sensor (HO2S)",
                    "Engine oil or unburnt fuel entering exhaust stream"
                ],
                driveCycleResolution: "Requires completing 3 consecutive universal drive cycles where the catalyst monitor runs and confirms operational efficiency > 95% without MIL trip."
            )
            
        case "P0171":
            return DTCKnowledge(
                title: "System Too Lean (Bank 1)",
                system: "Powertrain",
                severity: .warning,
                saeDescription: "The engine control module (ECM) detects that fuel trim corrections exceed rich limits (+20% to +25%) attempting to compensate for an unmetered air leak or inadequate fuel delivery on Bank 1.",
                commonCauses: [
                    "Vacuum leak in PCV hose, intake manifold gasket, or brake booster",
                    "Contaminated or failing Mass Air Flow (MAF) sensor hot-wire",
                    "Weak fuel pump, clogged fuel filter, or restricted fuel injector",
                    "Exhaust manifold crack before upstream wideband oxygen sensor"
                ],
                driveCycleResolution: isPerm ? "Requires 2 consecutive cold-to-hot drive cycles with Closed Loop fuel trim staying within ±10%." : nil
            )
            
        case "P0300":
            return DTCKnowledge(
                title: "Random / Multiple Cylinder Misfire Detected",
                system: "Powertrain",
                severity: .critical,
                saeDescription: "Crankshaft position sensor variation indicates random misfire across multiple engine cylinders exceeding the 200/1000 engine revolution emission threshold.",
                commonCauses: [
                    "Worn spark plugs or failing ignition coil packs",
                    "Low fuel pressure or fuel delivery starvation",
                    "Major intake vacuum leak downstream of throttle body",
                    "EGR valve stuck partially open"
                ],
                driveCycleResolution: isPerm ? "Requires 3 drive cycles verifying 0 misfire counts under cruise and idle loads." : nil
            )
            
        case "P0301":
            return DTCKnowledge(
                title: "Cylinder 1 Misfire Detected",
                system: "Powertrain",
                severity: .warning,
                saeDescription: "The ECM recorded excessive angular deceleration of the crankshaft during the expansion stroke of cylinder 1.",
                commonCauses: [
                    "Failing cylinder 1 ignition coil pack",
                    "Fouled, worn, or incorrectly gapped cylinder 1 spark plug",
                    "Clogged cylinder 1 fuel injector",
                    "Low compression on cylinder 1 (valves or piston rings)"
                ],
                driveCycleResolution: isPerm ? "Requires 2 drive cycles with zero misfire counts on cylinder 1." : nil
            )
            
        case "P0442":
            return DTCKnowledge(
                title: "EVAP System Small Leak Detected (0.040\")",
                system: "Powertrain",
                severity: .warning,
                saeDescription: "During engine-off natural vacuum or fuel tank pressure decay testing, the EVAP monitor detected pressure loss indicating a 0.040-inch vapor leak.",
                commonCauses: [
                    "Loose, worn, or cracked fuel filler cap seal",
                    "EVAP purge solenoid valve not sealing tightly",
                    "Cracked vapor line or canister vent valve sticking open"
                ],
                driveCycleResolution: isPerm ? "Requires 2 cold soak drive cycles with fuel tank between 15% and 85%." : nil
            )
            
        case "P0128":
            return DTCKnowledge(
                title: "Coolant Temp Below Thermostat Regulating Temp",
                system: "Powertrain",
                severity: .warning,
                saeDescription: "Engine coolant temperature failed to reach minimum target operating temperature within the calibrated time and air-mass threshold after engine start.",
                commonCauses: [
                    "Thermostat stuck open or opening prematurely",
                    "Engine Coolant Temperature (ECT) sensor drifted high resistance",
                    "Low engine coolant level"
                ],
                driveCycleResolution: isPerm ? "Requires 2 cold start drive cycles reaching > 85°C operating temp." : nil
            )
            
        default:
            return DTCKnowledge(
                title: "Diagnostic Trouble Code \(code)",
                system: code.starts(with: "P") ? "Powertrain" : (code.starts(with: "C") ? "Chassis" : (code.starts(with: "B") ? "Body" : "Network")),
                severity: isPerm ? .critical : .warning,
                saeDescription: isPerm ?
                    "Permanent Diagnostic Trouble Code (Mode 0A) stored in ECU non-volatile memory per EPA & CARB emissions standards. Must be cleared automatically via verified vehicle drive cycles." :
                    "Standard SAE J1979 diagnostic fault recorded by the vehicle electronic control unit.",
                commonCauses: [
                    "Sensor wiring harness corrosion or intermittent connection",
                    "Component wear or mechanical out-of-range condition"
                ],
                driveCycleResolution: isPerm ? "Requires 2-3 standard OBD-II driving cycles after physical component repair." : nil
            )
        }
    }
    
    // MARK: - Mode 09 PID 02: Vehicle Identification Number (VIN)
    static func decodeVIN(payload: [UInt8]) -> String? {
        // ISO-TP Mode 09 PID 02 payload contains a count byte or starts directly with ASCII bytes
        var asciiBytes = payload
        if let first = asciiBytes.first, first < 0x20 {
            // Drop count or index byte
            asciiBytes = Array(asciiBytes.dropFirst())
        }
        
        let rawStr = asciiBytes.compactMap { byte -> Character? in
            guard byte >= 0x20 && byte <= 0x7E else { return nil }
            return Character(UnicodeScalar(byte))
        }
        
        let vinCandidate = String(rawStr).trimmingCharacters(in: .whitespacesAndNewlines)
        if vinCandidate.count >= 17 {
            return String(vinCandidate.prefix(17))
        }
        return vinCandidate.isEmpty ? nil : vinCandidate
    }
    
    // MARK: - VIN Metadata WMI & Model Year Extractor
    static func decodeVINMetadata(vin: String) -> (make: String, year: Int, region: String) {
        guard vin.count >= 10 else {
            return ("Unknown Vehicle", 2020, "Global")
        }
        
        let wmi = String(vin.prefix(3)).uppercased()
        let yearChar = vin[vin.index(vin.startIndex, offsetBy: 9)]
        
        let make: String
        let region: String
        
        if wmi.starts(with: "WVW") || wmi.starts(with: "1VW") || wmi.starts(with: "3VW") {
            make = "Volkswagen"
            region = "Germany / USA"
        } else if wmi.starts(with: "WBA") || wmi.starts(with: "WBS") || wmi.starts(with: "4US") {
            make = "BMW"
            region = "Germany / USA"
        } else if wmi.starts(with: "WAU") || wmi.starts(with: "TRU") {
            make = "Audi"
            region = "Germany"
        } else if wmi.starts(with: "1HG") || wmi.starts(with: "2HG") || wmi.starts(with: "JHM") {
            make = "Honda"
            region = "Japan / North America"
        } else if wmi.starts(with: "1FA") || wmi.starts(with: "1FD") || wmi.starts(with: "1FT") {
            make = "Ford"
            region = "USA"
        } else if wmi.starts(with: "JM1") || wmi.starts(with: "JM3") {
            make = "Mazda"
            region = "Japan"
        } else if wmi.starts(with: "JT") || wmi.starts(with: "4T") {
            make = "Toyota"
            region = "Japan / USA"
        } else if wmi.starts(with: "WP0") || wmi.starts(with: "WP1") {
            make = "Porsche"
            region = "Germany"
        } else {
            make = "OBD-II Vehicle (\(wmi))"
            region = "International"
        }
        
        // Model Year 10th Character standard:
        // A=2010, B=2011, C=2012, D=2013, E=2014, F=2015, G=2016, H=2017, J=2018, K=2019, L=2020, M=2021, N=2022, P=2023, R=2024, S=2025, T=2026
        let yearMap: [Character: Int] = [
            "A": 2010, "B": 2011, "C": 2012, "D": 2013, "E": 2014,
            "F": 2015, "G": 2016, "H": 2017, "J": 2018, "K": 2019,
            "L": 2020, "M": 2021, "N": 2022, "P": 2023, "R": 2024,
            "S": 2025, "T": 2026
        ]
        let year = yearMap[yearChar] ?? 2018
        
        return (make, year, region)
    }
}
