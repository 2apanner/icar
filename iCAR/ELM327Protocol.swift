import Foundation

enum OBDError: LocalizedError {
    case noData
    case unableToConnect
    case canError
    case busInitError
    case stopped
    case unrecognizedResponse(String)
    case timeout
    case adapterDisconnected
    case invalidChecksum
    case bufferOverflow
    
    var errorDescription: String? {
        switch self {
        case .noData: return "ECU returned NO DATA (PID not supported or ignition OFF)"
        case .unableToConnect: return "Adapter reports UNABLE TO CONNECT to vehicle bus"
        case .canError: return "CAN bus communication collision or timing error"
        case .busInitError: return "Vehicle bus initialization failed"
        case .stopped: return "Adapter communication stopped prematurely"
        case .unrecognizedResponse(let resp): return "Unrecognized ELM response: \(resp)"
        case .timeout: return "ECU command timed out"
        case .adapterDisconnected: return "Hardware adapter disconnected"
        case .invalidChecksum: return "Frame checksum verification failed"
        case .bufferOverflow: return "UART receive buffer overflow"
        }
    }
}

protocol TransportProtocol: AnyObject {
    func connect() async throws
    func disconnect()
    func send(raw: String, timeout: TimeInterval) async throws -> String
    var isConnected: Bool { get }
}

/// Thread-safe half-duplex command mutex for ELM327 microcontrollers
actor ELM327CommandQueue {
    private let transport: TransportProtocol
    private var isExecuting = false
    
    init(transport: TransportProtocol) {
        self.transport = transport
    }
    
    func execute(command: String, timeout: TimeInterval = 3.0) async throws -> [String] {
        let cleanCmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawResponse = try await transport.send(raw: cleanCmd + "\r", timeout: timeout)
        return try sanitizeAndTokenize(rawResponse, sentCommand: cleanCmd)
    }
    
    private func sanitizeAndTokenize(_ raw: String, sentCommand: String) throws -> [String] {
        // Strip carriage returns, split into lines, remove empty spaces
        let rawLines = raw.replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var cleanLines: [String] = []
        for line in rawLines {
            let normalized = line.replacingOccurrences(of: " ", with: "").uppercased()
            
            // Check for terminal error tokens
            if normalized == "UNABLETOCONNECT" {
                throw OBDError.unableToConnect
            } else if normalized == "CANERROR" {
                throw OBDError.canError
            } else if normalized.contains("BUSINIT") && normalized.contains("ERROR") {
                throw OBDError.busInitError
            } else if normalized == "STOPPED" {
                throw OBDError.stopped
            } else if normalized == "?" {
                throw OBDError.unrecognizedResponse(line)
            }
            
            // Filter out command echoes and SEARCHING prompts
            if normalized.starts(with: "SEARCHING") || normalized == sentCommand.replacingOccurrences(of: " ", with: "").uppercased() {
                continue
            }
            
            cleanLines.append(line)
        }
        
        return cleanLines
    }
}
