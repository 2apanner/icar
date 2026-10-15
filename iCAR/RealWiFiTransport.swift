import Foundation
import Network

/// Real Wi-Fi TCP Transport Engine for Wi-Fi ELM327 OBD-II Gateways
/// Communicates over TCP sockets (Default 192.168.0.10:35000) using Apple Network.framework
class RealWiFiTransport: TransportProtocol {
    private var connection: NWConnection?
    private let host: String
    private let port: UInt16
    private var queue = DispatchQueue(label: "com.icar.wifi.transport")
    
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var sendContinuation: CheckedContinuation<String, Error>?
    private var sendTimeoutWorkItem: DispatchWorkItem?
    
    private let rxBuffer = NSMutableData()
    private(set) var isConnected: Bool = false
    
    var onRawChunkReceived: ((String) -> Void)?
    
    init(host: String = "192.168.0.10", port: UInt16 = 35000) {
        self.host = host
        self.port = port
    }
    
    func connect() async throws {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(integerLiteral: 35000)
        
        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        self.connection = conn
        
        return try await withCheckedThrowingContinuation { continuation in
            self.connectContinuation = continuation
            
            conn.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.isConnected = true
                    self.startReading()
                    self.connectContinuation?.resume(returning: ())
                    self.connectContinuation = nil
                    
                case .failed(let error):
                    self.isConnected = false
                    self.connectContinuation?.resume(throwing: error)
                    self.connectContinuation = nil
                    
                case .cancelled:
                    self.isConnected = false
                    
                default:
                    break
                }
            }
            
            conn.start(queue: self.queue)
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }
    
    func send(raw: String, timeout: TimeInterval) async throws -> String {
        guard isConnected, let conn = connection else {
            throw OBDError.adapterDisconnected
        }
        
        guard let data = raw.data(using: .ascii) else {
            throw OBDError.unrecognizedResponse(raw)
        }
        
        rxBuffer.length = 0
        
        return try await withCheckedThrowingContinuation { continuation in
            self.sendContinuation = continuation
            
            let timeoutItem = DispatchWorkItem { [weak self] in
                guard let self = self, let cont = self.sendContinuation else { return }
                self.sendContinuation = nil
                cont.resume(throwing: OBDError.timeout)
            }
            self.sendTimeoutWorkItem = timeoutItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
            
            conn.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    self?.sendTimeoutWorkItem?.cancel()
                    self?.sendContinuation?.resume(throwing: error)
                    self?.sendContinuation = nil
                }
            })
        }
    }
    
    private func startReading() {
        guard let conn = connection else { return }
        
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let chunk = data, !chunk.isEmpty {
                self.rxBuffer.append(chunk)
                
                if let ascii = String(data: chunk, encoding: .ascii) {
                    self.onRawChunkReceived?(ascii)
                }
                
                if let full = String(data: self.rxBuffer as Data, encoding: .ascii), full.contains(">") {
                    self.sendTimeoutWorkItem?.cancel()
                    self.sendTimeoutWorkItem = nil
                    
                    if let cont = self.sendContinuation {
                        self.sendContinuation = nil
                        cont.resume(returning: full)
                    }
                }
            }
            
            if !isComplete && error == nil && self.isConnected {
                self.startReading()
            }
        }
    }
}
