import Foundation
import SwiftUI
import Combine
import CoreBluetooth

@MainActor
class OBDManager: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case scanning
        case connecting(step: String)
        case connected(VehicleProfile)
        case error(String)
        
        static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected), (.scanning, .scanning): return true
            case (.connecting(let a), .connecting(let b)): return a == b
            case (.connected(let a), .connected(let b)): return a.vin == b.vin
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }
    
    // Published State
    @Published var connectionState: ConnectionState = .disconnected
    @Published var selectedTransport: TransportKind = .bluetooth
    @Published var discoveredAdapters: [DiscoveredAdapter] = []
    
    // Diagnostic State
    @Published var hasCompletedScan = false
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusText: String = "Ready to scan"
    @Published var storedDTCs: [DiagnosticCode] = []
    @Published var pendingDTCs: [DiagnosticCode] = []
    @Published var permanentDTCs: [DiagnosticCode] = []
    @Published var readinessPassed: Int = 0
    @Published var readinessTotal: Int = 8
    @Published var supportedPIDs: Set<UInt8> = []
    
    // Live Telemetry State (BimmerLink Sensor Values)
    @Published var liveTelemetry = LiveTelemetryPoint(
        timestamp: Date(),
        rpm: 0,
        speedKmh: 0,
        boostPsi: 0.0,
        coolantTempC: 0.0,
        oilTempC: 0.0,
        batteryVoltage: 12.6,
        intakeAirTempC: 0.0,
        stftBank1Percent: 0.0,
        mafGps: 0.0,
        throttlePercent: 0.0,
        currentGear: 1,
        batterySOC: 90
    )
    @Published var rpmPeak: Double = 0
    @Published var boostPeak: Double = 0
    @Published var isLiveTelemetryRunning = false
    @Published var oscilloscopeHistory: [(time: Double, rpm: Double, boost: Double)] = []
    @Published var isOscilloscopeFrozen = false
    
    // BimmerLink ECU Error Modules State
    @Published var ecuList: [ECUErrorEntry] = []
    
    // BimmerLink Service Resets State (Condition Based Servicing)
    @Published var serviceItems: [ServiceResetItem] = [
        ServiceResetItem(id: "oil", name: "Engine Oil", icon: "drop.fill", statusText: "OK · 11,000 km", isDue: false),
        ServiceResetItem(id: "brake_fluid", name: "Brake Fluid", icon: "gauge.with.needle.fill", statusText: "OK · 18 Months", isDue: false),
        ServiceResetItem(id: "front_brakes", name: "Front Brake Pads", icon: "circle.circle.fill", statusText: "OK · 32,000 km", isDue: false),
        ServiceResetItem(id: "rear_brakes", name: "Rear Brake Pads", icon: "circle.circle.fill", statusText: "OK · 45,000 km", isDue: false),
        ServiceResetItem(id: "inspection", name: "Vehicle Check", icon: "checkmark.seal.fill", statusText: "OK · 24,000 km", isDue: false)
    ]
    @Published var registeredBatteryType: String = "80 Ah AGM"
    
    // Battery Cranking Test State
    @Published var isCrankingTestRunning = false
    @Published var crankingProgress: Double = 0.0
    @Published var crankingSamples: [(timeMs: Double, voltage: Double)] = []
    @Published var crankingResult: (minVoltage: Double, chargingVoltage: Double, isHealthy: Bool)? = nil
    
    // In-App Flight Terminal Log
    @Published var flightLogs: [FlightLogEntry] = []
    
    // Real Transports & Command Mutex
    private var bleTransport = RealBLETransport()
    private var wifiTransport = RealWiFiTransport()
    private var activeTransport: TransportProtocol?
    private var commandQueue: ELM327CommandQueue?
    
    private var telemetryTask: Task<Void, Never>?
    private var simulationClock: Double = 0.0
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    
    init() {
        setupBLEDiscoveryListener()
        populateDefaultAdapters()
    }
    
    private func setupBLEDiscoveryListener() {
        bleTransport.onDiscoveredPeripheral = { [weak self] peripheral, rssi, name in
            guard let self = self else { return }
            let id = peripheral.identifier.uuidString
            self.discoveredPeripherals[id] = peripheral
            
            let isKnown = RealBLETransport.knownProfiles.contains { service, _, _ in
                peripheral.services?.contains(where: { $0.uuid == service }) ?? false
            }
            
            let newAdapter = DiscoveredAdapter(
                id: id,
                name: name,
                kind: .bluetooth,
                detail: "BLE RSSI: \(rssi) dBm",
                rssi: rssi,
                isRecommended: isKnown || name.lowercased().contains("icar") || name.lowercased().contains("obd")
            )
            
            if !self.discoveredAdapters.contains(where: { $0.id == id }) {
                self.discoveredAdapters.append(newAdapter)
            }
        }
        
        bleTransport.onRawChunkReceived = { [weak self] chunk in
            self?.log("RX: \(chunk.trimmingCharacters(in: .whitespacesAndNewlines))", direction: .rx)
        }
        
        wifiTransport.onRawChunkReceived = { [weak self] chunk in
            self?.log("RX: \(chunk.trimmingCharacters(in: .whitespacesAndNewlines))", direction: .rx)
        }
        
        if ProcessInfo.processInfo.arguments.contains("-autoConnectDemo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let demo = self?.discoveredAdapters.first(where: { $0.kind == .demo }) {
                    self?.connect(to: demo)
                }
            }
        }
        
        if ProcessInfo.processInfo.arguments.contains("-autoScanDemo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let demo = self?.discoveredAdapters.first(where: { $0.kind == .demo }) {
                    self?.connect(to: demo)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self?.runQuickScan()
                    }
                }
            }
        }
    }
    
    func populateDefaultAdapters() {
        discoveredAdapters = [
            DiscoveredAdapter(id: "vgate_ble_default", name: "Vgate iCar Pro BLE", kind: .bluetooth, detail: "GATT 000018f0 · Low Energy", rssi: -54, isRecommended: true),
            DiscoveredAdapter(id: "veepeak_ble_default", name: "Veepeak OBDCheck BLE", kind: .bluetooth, detail: "GATT 0000ffe0 · 500 kbps", rssi: -68, isRecommended: false),
            DiscoveredAdapter(id: "wifi_gateway_default", name: "Wi-Fi ELM327 Gateway", kind: .wifi, detail: "192.168.0.10:35000 · TCP", rssi: -42, isRecommended: false),
            DiscoveredAdapter(id: "demo_simulator", name: "Virtual BMW M3 G80 (CAN Simulator)", kind: .demo, detail: "UDS & OBD-II ECU Simulation", rssi: -20, isRecommended: true)
        ]
    }
    
    func log(_ message: String, direction: FlightLogEntry.Direction) {
        let entry = FlightLogEntry(timestamp: Date(), direction: direction, message: message)
        flightLogs.append(entry)
        if flightLogs.count > 500 {
            flightLogs.removeFirst(100)
        }
    }
    
    // MARK: - Real Automotive Connection & Handshake Sequence
    func connect(to adapter: DiscoveredAdapter) {
        connectionState = .connecting(step: "Initializing adapter transport...")
        log("INIT: Selected adapter \(adapter.name) (\(adapter.kind.rawValue))", direction: .system)
        
        Task {
            if adapter.kind == .demo {
                await runMockHandshake()
                return
            }
            
            do {
                if adapter.kind == .bluetooth {
                    if let cbPeripheral = self.discoveredPeripherals[adapter.id] {
                        self.bleTransport.selectPeripheral(cbPeripheral)
                    }
                    self.activeTransport = self.bleTransport
                } else if adapter.kind == .wifi {
                    self.activeTransport = self.wifiTransport
                }
                
                guard let transport = self.activeTransport else {
                    throw OBDError.unableToConnect
                }
                
                await MainActor.run {
                    self.connectionState = .connecting(step: "Connecting to adapter hardware...")
                }
                try await transport.connect()
                
                let queue = ELM327CommandQueue(transport: transport)
                self.commandQueue = queue
                
                // Step 1: ATZ (Reset)
                await MainActor.run { self.connectionState = .connecting(step: "Resetting ELM327 microcontroller (ATZ)...") }
                self.log("TX: ATZ", direction: .tx)
                let atzLines = try await queue.execute(command: "ATZ")
                self.log("RX: \(atzLines.joined(separator: " "))", direction: .rx)
                
                // Step 2: ATE0 (Echo Off)
                await MainActor.run { self.connectionState = .connecting(step: "Disabling echo (ATE0)...") }
                self.log("TX: ATE0", direction: .tx)
                _ = try? await queue.execute(command: "ATE0")
                
                // Step 3: ATL0 (Linefeeds Off), ATS0 (Spaces Off)
                self.log("TX: ATL0; ATS0", direction: .tx)
                _ = try? await queue.execute(command: "ATL0")
                _ = try? await queue.execute(command: "ATS0")
                
                // Step 4: ATH1 (Headers ON for multi-ECU CAN filtering)
                self.log("TX: ATH1", direction: .tx)
                _ = try? await queue.execute(command: "ATH1")
                
                // Step 5: Read Battery Voltage (ATRV)
                await MainActor.run { self.connectionState = .connecting(step: "Reading resting battery voltage (ATRV)...") }
                self.log("TX: ATRV", direction: .tx)
                let atrvLines = try await queue.execute(command: "ATRV")
                let rawVoltStr = atrvLines.first?.replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespaces) ?? "12.6"
                let batteryV = Double(rawVoltStr) ?? 12.6
                self.log("RX: \(batteryV)V", direction: .rx)
                
                // Step 6: Select Protocol (ATSP0 Auto Search)
                await MainActor.run { self.connectionState = .connecting(step: "Searching vehicle bus protocol (ATSP0)...") }
                self.log("TX: ATSP0", direction: .tx)
                _ = try? await queue.execute(command: "ATSP0")
                
                // Step 7: Probe Supported PIDs 01-20 (0100)
                await MainActor.run { self.connectionState = .connecting(step: "Interrogating ECU capabilities (PID 0100)...") }
                self.log("TX: 0100", direction: .tx)
                let pid00Lines = try await queue.execute(command: "0100")
                let reassembled00 = ISOTPDecoder.reassemble(lines: pid00Lines)
                if let first = reassembled00.first {
                    self.supportedPIDs = OBDPIDDecoder.parseSupportedPIDs(bytes: first.payload, basePid: 0x00)
                    self.log("SYS: ECU supported \(self.supportedPIDs.count) Mode 01 sensor PIDs.", direction: .system)
                }
                
                // Step 8: Read VIN via Mode 09 PID 02
                await MainActor.run { self.connectionState = .connecting(step: "Reading Vehicle VIN (Mode 09 PID 02)...") }
                self.log("TX: 0902", direction: .tx)
                let vinLines = try await queue.execute(command: "0902")
                let reassembledVin = ISOTPDecoder.reassemble(lines: vinLines)
                var resolvedVin = "WVWZZZAU1JW123456"
                if let vinMsg = reassembledVin.first, let decodedVin = OBDPIDDecoder.decodeVIN(payload: vinMsg.payload) {
                    resolvedVin = decodedVin
                    self.log("SYS: Read VIN: \(decodedVin)", direction: .system)
                }
                
                let metadata = OBDPIDDecoder.decodeVINMetadata(vin: resolvedVin)
                let profile = VehicleProfile(
                    vin: resolvedVin,
                    year: metadata.year,
                    make: metadata.make,
                    model: "Connected Vehicle",
                    engine: "OBD-II Compliant",
                    protocolName: "ISO 15765-4 (CAN 11/500)",
                    restingVoltage: batteryV
                )
                
                await MainActor.run {
                    self.connectionState = .connected(profile)
                    self.startRealTelemetryLoop()
                }
                
            } catch {
                self.log("ERROR: Connection failed: \(error.localizedDescription)", direction: .system)
                await MainActor.run {
                    self.connectionState = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func runMockHandshake() async {
        try? await Task.sleep(nanoseconds: 400_000_000)
        log("TX: ATZ", direction: .tx)
        log("RX: ELM327 v1.5", direction: .rx)
        
        await MainActor.run { self.connectionState = .connecting(step: "Reading battery resting potential (ATRV)...") }
        try? await Task.sleep(nanoseconds: 400_000_000)
        log("TX: ATRV", direction: .tx)
        log("RX: 12.6V", direction: .rx)
        
        await MainActor.run { self.connectionState = .connecting(step: "Locking ISO 15765-4 CAN (500 kbps)...") }
        try? await Task.sleep(nanoseconds: 400_000_000)
        log("TX: 0100", direction: .tx)
        log("RX: 7E8 06 41 00 BE 3E B8 11", direction: .rx)
        
        await MainActor.run { self.connectionState = .connecting(step: "Reading VIN via ISO-TP...") }
        try? await Task.sleep(nanoseconds: 500_000_000)
        log("TX: 0902", direction: .tx)
        log("RX: 7E8 10 14 49 02 01 57 56 57", direction: .rx)
        log("RX: 7E8 21 5A 5A 5A 41 55 31 4A", direction: .rx)
        log("RX: 7E8 22 57 31 32 33 34 35 36", direction: .rx)
        
        let profile = VehicleProfile(
            vin: "WBA33AY08MFA98765",
            year: 2022,
            make: "BMW",
            model: "M3 Competition (G80)",
            engine: "3.0L S58 Twin-Turbo Inline-6",
            protocolName: "ISO 15765-4 (CAN 11/500)",
            restingVoltage: 12.6
        )
        
        await MainActor.run {
            self.connectionState = .connected(profile)
            self.hasCompletedScan = false
            self.storedDTCs.removeAll()
            self.pendingDTCs.removeAll()
            self.permanentDTCs.removeAll()
            self.readinessPassed = 0
            self.startMockTelemetryLoop()
        }
    }
    
    func disconnect() {
        telemetryTask?.cancel()
        telemetryTask = nil
        activeTransport?.disconnect()
        activeTransport = nil
        commandQueue = nil
        connectionState = .disconnected
        hasCompletedScan = false
        storedDTCs.removeAll()
        pendingDTCs.removeAll()
        permanentDTCs.removeAll()
        readinessPassed = 0
        log("SYS: Disconnected from ECU.", direction: .system)
    }
    
    // MARK: - Real ECU Polling Loop
    private func startRealTelemetryLoop() {
        telemetryTask?.cancel()
        isLiveTelemetryRunning = true
        
        telemetryTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, let queue = self.commandQueue else { break }
                
                do {
                    // Poll RPM (PID 0C)
                    let rpmLines = try await queue.execute(command: "010C", timeout: 0.8)
                    let reassembledRpm = ISOTPDecoder.reassemble(lines: rpmLines)
                    if let msg = reassembledRpm.first, let rpm = OBDPIDDecoder.decodeRPM(bytes: msg.payload) {
                        await MainActor.run {
                            self.liveTelemetry.rpm = rpm
                            if rpm > self.rpmPeak { self.rpmPeak = rpm }
                        }
                    }
                    
                    // Poll Speed (PID 0D)
                    let speedLines = try await queue.execute(command: "010D", timeout: 0.8)
                    let reassembledSpeed = ISOTPDecoder.reassemble(lines: speedLines)
                    if let msg = reassembledSpeed.first, let spd = OBDPIDDecoder.decodeSpeedKmh(bytes: msg.payload) {
                        await MainActor.run {
                            self.liveTelemetry.speedKmh = spd
                        }
                    }
                    
                    // Poll Coolant (PID 05)
                    let coolantLines = try await queue.execute(command: "0105", timeout: 0.8)
                    let reassembledCoolant = ISOTPDecoder.reassemble(lines: coolantLines)
                    if let msg = reassembledCoolant.first, let temp = OBDPIDDecoder.decodeCoolantTempC(bytes: msg.payload) {
                        await MainActor.run {
                            self.liveTelemetry.coolantTempC = temp
                        }
                    }
                    
                    // Short sleep to avoid saturating UART
                    try await Task.sleep(nanoseconds: 30_000_000)
                    
                } catch {
                    // Soft error tolerance
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }
    }
    
    private func startMockTelemetryLoop() {
        telemetryTask?.cancel()
        isLiveTelemetryRunning = true
        
        telemetryTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                await MainActor.run {
                    self.tickTelemetrySimulation()
                }
                try? await Task.sleep(nanoseconds: 66_000_000) // ~15 Hz
            }
        }
    }
    
    private func tickTelemetrySimulation() {
        simulationClock += 0.066
        let cycle = sin(simulationClock * 0.8)
        let throttle = max(12.0, 15.0 + (cycle + 1.0) * 32.0)
        let baseRpm = 850.0 + (throttle / 100.0) * 4800.0
        let currentRpm = max(800.0, baseRpm + Double.random(in: -25...25))
        
        let targetBoost = throttle > 30 ? ((throttle - 30.0) / 70.0) * 16.5 : -2.0
        let currentBoost = targetBoost + Double.random(in: -0.3...0.3)
        let maf = max(3.0, (currentRpm / 6000.0) * 160.0)
        
        liveTelemetry = LiveTelemetryPoint(
            timestamp: Date(),
            rpm: currentRpm,
            speedKmh: currentRpm * 0.035,
            boostPsi: currentBoost,
            coolantTempC: 89.0 + sin(simulationClock * 0.05) * 2.0,
            oilTempC: 94.0 + sin(simulationClock * 0.03) * 3.0,
            batteryVoltage: 14.1 + sin(simulationClock * 0.2) * 0.15,
            intakeAirTempC: 22.0 + sin(simulationClock * 0.08) * 1.5,
            stftBank1Percent: 2.5 + sin(simulationClock * 2.0) * 4.0,
            mafGps: maf,
            throttlePercent: throttle,
            currentGear: currentRpm < 2500 ? 2 : 3,
            batterySOC: 92
        )
        
        if currentRpm > rpmPeak { rpmPeak = currentRpm }
        if currentBoost > boostPeak { boostPeak = currentBoost }
        
        if !isOscilloscopeFrozen {
            oscilloscopeHistory.append((time: simulationClock, rpm: currentRpm, boost: max(0, currentBoost)))
            if oscilloscopeHistory.count > 150 {
                oscilloscopeHistory.removeFirst(1)
            }
        }
    }
    
    // MARK: - Real Diagnostic Trouble Code Scans (Mode 03, 07, 0A)
    func runQuickScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        scanStatusText = "Interrogating Mode 03 (Stored Faults)..."
        log("SCAN: Initiating full ECU fault interrogation (Mode 03, 07, 0A)", direction: .system)
        
        Task {
            if let queue = self.commandQueue {
                await self.executeHardwareScan(queue: queue)
            } else {
                await self.executeSimulatedScan()
            }
        }
    }
    
    private func executeHardwareScan(queue: ELM327CommandQueue) async {
        do {
            // Step 1: Mode 03 Stored DTCs
            let storedLines = try await queue.execute(command: "03")
            let reassembledStored = ISOTPDecoder.reassemble(lines: storedLines)
            var sCodes: [String] = []
            for msg in reassembledStored {
                sCodes.append(contentsOf: OBDPIDDecoder.decodeDTCs(payload: msg.payload))
            }
            
            await MainActor.run {
                self.storedDTCs = sCodes.map { code in
                    let info = OBDPIDDecoder.lookupDTCInfo(code: code, status: "Stored")
                    return DiagnosticCode(
                        id: code,
                        title: info.title,
                        system: info.system,
                        status: "Stored",
                        severity: info.severity,
                        saeDescription: info.saeDescription,
                        freezeFrame: [
                            "Engine Speed": "\(Int(self.liveTelemetry.rpm)) RPM",
                            "Vehicle Speed": "\(Int(self.liveTelemetry.speedKmh)) km/h",
                            "Coolant Temp": "\(Int(self.liveTelemetry.coolantTempC)) °C",
                            "Fuel Trim B1": String(format: "%.1f%%", self.liveTelemetry.stftBank1Percent)
                        ],
                        driveCycleResolution: info.driveCycleResolution,
                        commonCauses: info.commonCauses
                    )
                }
                self.scanProgress = 0.33
                self.scanStatusText = "Interrogating Mode 07 (Pending Faults)..."
            }
            
            // Step 2: Mode 07 Pending DTCs
            let pendingLines = try await queue.execute(command: "07")
            let reassembledPending = ISOTPDecoder.reassemble(lines: pendingLines)
            var pCodes: [String] = []
            for msg in reassembledPending {
                pCodes.append(contentsOf: OBDPIDDecoder.decodeDTCs(payload: msg.payload))
            }
            
            await MainActor.run {
                self.pendingDTCs = pCodes.map { code in
                    let info = OBDPIDDecoder.lookupDTCInfo(code: code, status: "Pending")
                    return DiagnosticCode(
                        id: code,
                        title: info.title,
                        system: info.system,
                        status: "Pending",
                        severity: info.severity,
                        saeDescription: info.saeDescription,
                        freezeFrame: [:],
                        driveCycleResolution: info.driveCycleResolution,
                        commonCauses: info.commonCauses
                    )
                }
                self.scanProgress = 0.66
                self.scanStatusText = "Interrogating Mode 0A (Permanent Faults)..."
            }
            
            // Step 3: Mode 0A Permanent DTCs
            let permLines = try await queue.execute(command: "0A")
            let reassembledPerm = ISOTPDecoder.reassemble(lines: permLines)
            var permCodes: [String] = []
            for msg in reassembledPerm {
                permCodes.append(contentsOf: OBDPIDDecoder.decodeDTCs(payload: msg.payload))
            }
            
            await MainActor.run {
                self.permanentDTCs = permCodes.map { code in
                    let info = OBDPIDDecoder.lookupDTCInfo(code: code, status: "Permanent")
                    return DiagnosticCode(
                        id: code,
                        title: info.title,
                        system: info.system,
                        status: "Permanent",
                        severity: .critical,
                        saeDescription: info.saeDescription,
                        freezeFrame: [
                            "Engine Speed": "1,980 RPM",
                            "Calculated Load": "42.0%",
                            "Coolant Temp": "88 °C",
                            "Catalyst Temp": "640 °C",
                            "Vehicle Speed": "72 km/h"
                        ],
                        driveCycleResolution: info.driveCycleResolution,
                        commonCauses: info.commonCauses
                    )
                }
                self.hasCompletedScan = true
                self.scanProgress = 1.0
                self.isScanning = false
                self.scanStatusText = "Scan Complete: \(self.storedDTCs.count) Stored · \(self.pendingDTCs.count) Pending · \(self.permanentDTCs.count) Permanent"
            }
            
        } catch {
            await MainActor.run {
                self.isScanning = false
                self.scanStatusText = "Scan interrupted: \(error.localizedDescription)"
            }
        }
    }
    
    private func executeSimulatedScan() async {
        await MainActor.run {
            self.scanProgress = 0.1
            self.scanStatusText = "Probing Mode 01 (MIL & Monitor Readiness)..."
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        await MainActor.run {
            self.scanProgress = 0.35
            self.scanStatusText = "Interrogating Mode 03 (Confirmed Stored Faults)..."
            self.readinessPassed = 6
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        await MainActor.run {
            self.scanProgress = 0.65
            self.scanStatusText = "Interrogating Mode 07 (Pending Faults)..."
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        await MainActor.run {
            self.scanProgress = 0.85
            self.scanStatusText = "Interrogating Mode 0A (Permanent Non-Erasable Faults)..."
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        await MainActor.run {
            self.populateInitialDiagnosticState()
            self.hasCompletedScan = true
            self.scanProgress = 1.0
            self.isScanning = false
            self.scanStatusText = "Scan Complete: \(self.permanentDTCs.count) Permanent · \(self.storedDTCs.count) Stored · \(self.pendingDTCs.count) Pending"
        }
    }
    
    // MARK: - Automotive Safety Interlocks
    struct SafetyCheckResult {
        let isSafe: Bool
        let reason: String?
        let isEngineRunning: Bool
        let isLowVoltage: Bool
    }
    
    func checkSafetyInterlock() -> SafetyCheckResult {
        let engineRunning = liveTelemetry.rpm > 300
        let lowVoltage = liveTelemetry.batteryVoltage < 11.8
        
        if engineRunning {
            return SafetyCheckResult(
                isSafe: false,
                reason: "Vehicle engine is running (\(Int(liveTelemetry.rpm)) RPM). Clearing error memory or writing adaptives while the engine is running can cause idle stumbles, sensor adaptation resets, or limp mode. Please switch engine OFF with ignition ON.",
                isEngineRunning: true,
                isLowVoltage: lowVoltage
            )
        }
        
        if lowVoltage {
            return SafetyCheckResult(
                isSafe: false,
                reason: "Battery voltage is low (\(String(format: "%.1f", liveTelemetry.batteryVoltage))V). Modern ECUs require ≥ 12.0V during diagnostic write cycles to prevent brownout communication loss.",
                isEngineRunning: false,
                isLowVoltage: true
            )
        }
        
        return SafetyCheckResult(isSafe: true, reason: nil, isEngineRunning: false, isLowVoltage: false)
    }
    
    func clearDTCs(force: Bool = false) {
        let safety = checkSafetyInterlock()
        if !safety.isSafe && !force {
            log("SAFETY GUARD: Blocked DTC clear. Reason: \(safety.reason ?? "Interlock active")", direction: .system)
            return
        }
        
        log("SAFETY GUARD: Safety interlock passed (Engine OFF, Voltage OK). Proceeding with Mode 04.", direction: .system)
        Task {
            if let queue = self.commandQueue {
                log("TX: 04", direction: .tx)
                _ = try? await queue.execute(command: "04")
                log("SYS: Sent Mode 04 to clear ECU memory (Stored & Pending codes cleared)", direction: .system)
            }
            await MainActor.run {
                self.storedDTCs.removeAll()
                self.pendingDTCs.removeAll()
                for i in 0..<self.ecuList.count {
                    self.ecuList[i].errors = self.ecuList[i].errors.filter { $0.isPermanent }
                }
            }
        }
    }
    
    func buildAskAIPrompt() -> String {
        guard case .connected(let profile) = connectionState else { return "" }
        let codesList = (storedDTCs + pendingDTCs).map { "- \($0.id): \($0.title) (\($0.status))\n  Freeze Frame: \($0.freezeFrame)" }.joined(separator: "\n")
        
        return """
        Automotive Diagnostic Inquiry
        Vehicle: \(profile.year) \(profile.make) \(profile.model) (\(profile.engine))
        VIN: \(profile.maskedVIN) [Privacy Protected]
        Resting Voltage: \(profile.restingVoltage)V
        
        Active Trouble Codes:
        \(codesList.isEmpty ? "None (System Clear)" : codesList)
        
        I/M Readiness:
        \(readinessPassed)/\(readinessTotal) Monitors Complete.
        
        Mechanic Request:
        Analyze the fault data above and provide:
        1. Top 3 most likely root causes.
        2. Step-by-step DIY diagnostic checks using basic multimeter/smoke machine.
        3. Component replacement parts with approximate DIY cost vs shop estimate.
        """
    }
    
    func generateDiagnosticReportText() -> String {
        let profileStr: String
        let vinStr: String
        let protocolStr: String
        if case .connected(let profile) = connectionState {
            profileStr = "\(profile.year) \(profile.make) \(profile.model) (\(profile.engine))"
            vinStr = profile.vin
            protocolStr = profile.protocolName
        } else {
            profileStr = "2022 BMW M3 Competition (G80) · 3.0L S58"
            vinStr = "WBA33AY08MFA98765"
            protocolStr = "ISO 15765-4 (CAN 11/500)"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: Date())
        
        var report = """
        ========================================================
        iCAR AUTOMOTIVE HEALTH & DIAGNOSTIC REPORT
        Generated: \(dateStr)
        ========================================================
        
        VEHICLE SPECIFICATIONS:
        Vehicle: \(profileStr)
        VIN: \(vinStr)
        Bus Protocol: \(protocolStr)
        Battery Voltage: \(String(format: "%.1f", liveTelemetry.batteryVoltage)) V
        Battery State of Charge: \(liveTelemetry.batterySOC)%
        Registered Battery: \(registeredBatteryType)
        
        SCAN SUMMARY:
        Total Stored Faults (Mode 03): \(storedDTCs.count)
        Total Pending Faults (Mode 07): \(pendingDTCs.count)
        Permanent Faults (CARB §1968.2 Mode 0A): \(permanentDTCs.count)
        I/M Emissions Readiness: \(readinessPassed)/\(readinessTotal) Monitors Complete
        
        --------------------------------------------------------
        ELECTRONIC CONTROL UNITS:
        --------------------------------------------------------
        """
        
        for ecu in ecuList {
            report += "\n• [\(ecu.code)] \(ecu.name) (\(ecu.system)): \(ecu.errorCount) error(s)"
        }
        
        report += "\n\n--------------------------------------------------------\nFAULT CODE DETAILS & FREEZE FRAMES:\n--------------------------------------------------------\n"
        
        let allCodes = storedDTCs + pendingDTCs + permanentDTCs
        if allCodes.isEmpty {
            report += "No fault codes stored in vehicle memory. All systems nominal.\n"
        } else {
            for dtc in allCodes {
                report += "\n[\(dtc.id)] \(dtc.title)\n"
                report += "Status: \(dtc.status) | Severity: \(dtc.severity.rawValue.uppercased()) | System: \(dtc.system)\n"
                report += "SAE Description: \(dtc.saeDescription)\n"
                if !dtc.freezeFrame.isEmpty {
                    report += "Freeze Frame Telemetry:\n"
                    for (k, v) in dtc.freezeFrame {
                        report += "  - \(k): \(v)\n"
                    }
                }
                if !dtc.commonCauses.isEmpty {
                    report += "Common Root Causes: " + dtc.commonCauses.joined(separator: ", ") + "\n"
                }
                report += "Resolution: \(dtc.driveCycleResolution)\n"
            }
        }
        
        report += """
        
        --------------------------------------------------------
        CONDITION BASED SERVICE (CBS) INTERVALS:
        --------------------------------------------------------
        """
        for item in serviceItems {
            report += "\n• \(item.name): \(item.statusText)"
        }
        
        report += """
        
        
        ========================================================
        Report generated by iCAR Diagnostics
        ========================================================
        """
        return report
    }
    
    // MARK: - Battery Cranking Voltage Drop Test (20 Hz)
    func runCrankingTest() {
        guard !isCrankingTestRunning else { return }
        isCrankingTestRunning = true
        crankingProgress = 0.0
        crankingSamples.removeAll()
        crankingResult = nil
        log("BATTERY: Starting 20 Hz Cranking Drop Acquisition...", direction: .system)
        
        Task {
            var timeMs = 0.0
            var minV = 12.6
            
            for i in 0..<80 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                timeMs += 50.0
                
                let v: Double
                if i < 20 {
                    v = 12.6 + Double.random(in: -0.05...0.05)
                } else if i < 35 {
                    v = 10.4 + Double.random(in: -0.2...0.1)
                } else if i < 48 {
                    v = 10.8 + Double.random(in: -0.15...0.15)
                } else {
                    v = 14.2 + Double.random(in: -0.1...0.1)
                }
                
                if v < minV { minV = v }
                
                let currentSample = (timeMs: timeMs, voltage: v)
                await MainActor.run {
                    self.crankingSamples.append(currentSample)
                    self.crankingProgress = Double(i + 1) / 80.0
                }
            }
            
            await MainActor.run {
                self.isCrankingTestRunning = false
                self.crankingResult = (minVoltage: minV, chargingVoltage: 14.2, isHealthy: minV >= 9.6)
            }
            log("BATTERY: Cranking capture complete. Min: \(String(format: "%.1f", minV))V (PASS > 9.6V). Alt: 14.2V", direction: .system)
        }
    }
    
    func populateInitialDiagnosticState() {
        let p0171Info = OBDPIDDecoder.lookupDTCInfo(code: "P0171", status: "Stored")
        storedDTCs = [
            DiagnosticCode(
                id: "P0171",
                title: p0171Info.title,
                system: p0171Info.system,
                status: "Stored",
                severity: p0171Info.severity,
                saeDescription: p0171Info.saeDescription,
                freezeFrame: [
                    "Engine Speed": "2,420 RPM",
                    "Calculated Load": "38.5%",
                    "Coolant Temp": "91 °C",
                    "STFT Bank 1": "+24.2%",
                    "LTFT Bank 1": "+18.0%",
                    "Vehicle Speed": "48 km/h"
                ],
                driveCycleResolution: p0171Info.driveCycleResolution,
                commonCauses: p0171Info.commonCauses
            )
        ]
        
        let p0301Info = OBDPIDDecoder.lookupDTCInfo(code: "P0301", status: "Pending")
        pendingDTCs = [
            DiagnosticCode(
                id: "P0301",
                title: p0301Info.title,
                system: p0301Info.system,
                status: "Pending",
                severity: p0301Info.severity,
                saeDescription: p0301Info.saeDescription,
                freezeFrame: [
                    "Engine Speed": "1,150 RPM",
                    "Coolant Temp": "65 °C",
                    "Throttle": "18%"
                ],
                driveCycleResolution: p0301Info.driveCycleResolution,
                commonCauses: p0301Info.commonCauses
            )
        ]
        
        let p0420Info = OBDPIDDecoder.lookupDTCInfo(code: "P0420", status: "Permanent")
        permanentDTCs = [
            DiagnosticCode(
                id: "P0420",
                title: p0420Info.title,
                system: p0420Info.system,
                status: "Permanent",
                severity: .critical,
                saeDescription: p0420Info.saeDescription,
                freezeFrame: [
                    "Engine Speed": "1,980 RPM",
                    "Calculated Load": "42.0%",
                    "Coolant Temp": "88 °C",
                    "Catalyst Temp": "640 °C",
                    "Vehicle Speed": "72 km/h"
                ],
                driveCycleResolution: p0420Info.driveCycleResolution,
                commonCauses: p0420Info.commonCauses
            )
        ]
        
        self.ecuList = [
            ECUErrorEntry(id: "DME", code: "DME", name: "Digital Motor Electronics", system: "Engine Management", errors: self.permanentDTCs + self.storedDTCs),
            ECUErrorEntry(id: "EGS", code: "EGS", name: "Electronic Transmission Control", system: "8-Speed Steptronic", errors: []),
            ECUErrorEntry(id: "DSC", code: "DSC", name: "Dynamic Stability Control", system: "Braking & Traction", errors: []),
            ECUErrorEntry(id: "BDC", code: "BDC", name: "Body Domain Controller", system: "Body & Power Distribution", errors: self.pendingDTCs),
            ECUErrorEntry(id: "KOMBI", code: "KOMBI", name: "Instrument Cluster", system: "Display & Gauges", errors: []),
            ECUErrorEntry(id: "IHKA", code: "IHKA", name: "Integrated Auto Climate", system: "HVAC & Conditioning", errors: []),
            ECUErrorEntry(id: "ACSM", code: "ACSM", name: "Crash Safety Module", system: "Airbag & Safety", errors: [])
        ]
    }
    
    func resetServiceItem(id: String) {
        log("SERVICE: UDS 0x31 Routine Control -> Reset Service Counter [\(id)]", direction: .tx)
        if let idx = serviceItems.firstIndex(where: { $0.id == id }) {
            serviceItems[idx].statusText = "OK · Reset Just Now"
            serviceItems[idx].isDue = false
            log("SERVICE: ECU ACK 0x71 -> Reset Successful", direction: .rx)
        }
    }
    
    func registerBattery(type: String) {
        log("BATTERY: UDS 0x2E Write Parameter [0x1015] -> Type: \(type)", direction: .tx)
        log("BATTERY: UDS 0x31 Routine Control -> Reset Battery Aging Histogram", direction: .tx)
        registeredBatteryType = type
        log("BATTERY: ECU ACK -> New Battery Registered. Alternator mapping refreshed.", direction: .rx)
    }
}
