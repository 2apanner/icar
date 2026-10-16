import Foundation
import CoreBluetooth

/// Real CoreBluetooth BLE 4.0 / 5.x Transport Engine
/// Implements auto-GATT profile discovery, MTU ring-buffering, and half-duplex command execution.
class RealBLETransport: NSObject, TransportProtocol, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    private var isCentralReady = false
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var sendContinuation: CheckedContinuation<String, Error>?
    private var sendTimeoutWorkItem: DispatchWorkItem?
    
    private let rxBuffer = NSMutableData()
    private(set) var isConnected: Bool = false
    
    // Known BLE OBD-II GATT Profiles
    static let knownProfiles: [(service: CBUUID, write: CBUUID, notify: CBUUID)] = [
        // Vgate iCar Pro / IOS-Vlink
        (CBUUID(string: "18F0"), CBUUID(string: "2AF1"), CBUUID(string: "2AF0")),
        // Veepeak / Carista / Generic FFE0
        (CBUUID(string: "FFE0"), CBUUID(string: "FFE1"), CBUUID(string: "FFE1")),
        // OBDLink CX / vLinker BLE
        (CBUUID(string: "FFF0"), CBUUID(string: "FFF2"), CBUUID(string: "FFF1")),
        // Nordic UART Service (NUS)
        (CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"),
         CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"),
         CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"))
    ]
    
    private var isScanningRequested = false
    
    var onDiscoveredPeripheral: ((CBPeripheral, Int, String) -> Void)?
    var onRawChunkReceived: ((String) -> Void)?
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func startScan() {
        isScanningRequested = true
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    func stopScan() {
        isScanningRequested = false
        centralManager.stopScan()
    }
    
    func selectPeripheral(_ target: CBPeripheral) {
        self.peripheral = target
        self.peripheral?.delegate = self
    }
    
    // MARK: - TransportProtocol
    func connect() async throws {
        guard let p = peripheral else {
            throw OBDError.unableToConnect
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.connectContinuation = continuation
            self.centralManager.connect(p, options: nil)
            
            // Safety connection timeout: 8 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
                guard let self = self, let cont = self.connectContinuation else { return }
                self.connectContinuation = nil
                cont.resume(throwing: OBDError.unableToConnect)
            }
        }
    }
    
    func disconnect() {
        if let p = peripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        isConnected = false
        peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
    }
    
    func send(raw: String, timeout: TimeInterval) async throws -> String {
        guard isConnected, let p = peripheral, let writeChar = writeCharacteristic else {
            throw OBDError.adapterDisconnected
        }
        
        guard let data = raw.data(using: .ascii) else {
            throw OBDError.unrecognizedResponse(raw)
        }
        
        rxBuffer.length = 0 // Clear receive buffer
        
        return try await withCheckedThrowingContinuation { continuation in
            self.sendContinuation = continuation
            
            // Set safety timeout
            let timeoutItem = DispatchWorkItem { [weak self] in
                guard let self = self, let cont = self.sendContinuation else { return }
                self.sendContinuation = nil
                cont.resume(throwing: OBDError.timeout)
            }
            self.sendTimeoutWorkItem = timeoutItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
            
            // Send payload via BLE
            let writeType: CBCharacteristicWriteType = writeChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            p.writeValue(data, for: writeChar, type: writeType)
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isCentralReady = central.state == .poweredOn
        if isCentralReady && isScanningRequested {
            startScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        onDiscoveredPeripheral?(peripheral, RSSI.intValue, name)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stopScan()
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectContinuation?.resume(throwing: error ?? OBDError.unableToConnect)
        connectContinuation = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        sendContinuation?.resume(throwing: OBDError.adapterDisconnected)
        sendContinuation = nil
    }
    
    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            connectContinuation?.resume(throwing: OBDError.unableToConnect)
            connectContinuation = nil
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for char in characteristics {
            // Check for Notify/Indicate characteristic
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                if notifyCharacteristic == nil {
                    notifyCharacteristic = char
                    peripheral.setNotifyValue(true, for: char)
                }
            }
            
            // Check for Write characteristic
            if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                if writeCharacteristic == nil {
                    writeCharacteristic = char
                }
            }
        }
        
        // If both characteristics found, connection handshake is unlocked
        if writeCharacteristic != nil && notifyCharacteristic != nil && !isConnected {
            isConnected = true
            connectContinuation?.resume(returning: ())
            connectContinuation = nil
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let chunk = characteristic.value else { return }
        rxBuffer.append(chunk)
        
        if let asciiChunk = String(data: chunk, encoding: .ascii) {
            onRawChunkReceived?(asciiChunk)
        }
        
        // Check if ELM327 command terminator ('>') has arrived
        if let fullString = String(data: rxBuffer as Data, encoding: .ascii), fullString.contains(">") {
            sendTimeoutWorkItem?.cancel()
            sendTimeoutWorkItem = nil
            
            if let continuation = sendContinuation {
                sendContinuation = nil
                continuation.resume(returning: fullString)
            }
        }
    }
}
