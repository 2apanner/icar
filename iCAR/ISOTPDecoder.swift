import Foundation

/// ISO-TP (ISO 15765-2) Multi-Frame Reassembly Engine
/// Reassembles multi-line CAN payloads segmented across Single Frame (SF), First Frame (FF),
/// and Consecutive Frames (CF), partitioned strictly by ECU header (e.g. 7E8 Engine vs 7E9 Transmission).
enum ISOTPDecoder {
    struct ReassembledMessage {
        let ecuHeader: String
        let service: UInt8
        let pid: UInt8?
        let payload: [UInt8]
    }
    
    enum FrameType {
        case singleFrame(length: Int, data: [UInt8])
        case firstFrame(totalLength: Int, data: [UInt8])
        case consecutiveFrame(sequence: Int, data: [UInt8])
        case raw(data: [UInt8])
    }
    
    static func reassemble(lines: [String]) -> [ReassembledMessage] {
        // Group lines by ECU CAN ID (e.g., "7E8", "7E9")
        var ecuBuckets: [String: [String]] = [:]
        
        for line in lines {
            let tokens = line.split(separator: " ").map(String.init)
            guard !tokens.isEmpty else { continue }
            
            // Check if first token is an ECU header (3 hex characters like 7E8, 7E9, 18DAF110)
            if tokens[0].count == 3 || tokens[0].count == 8, let _ = UInt32(tokens[0], radix: 16) {
                let ecu = tokens[0]
                let frameBytes = tokens.dropFirst().joined(separator: " ")
                ecuBuckets[ecu, default: []].append(frameBytes)
            } else {
                // Adapter with ATH0 (Headers OFF)
                ecuBuckets["UNKNOWN", default: []].append(line)
            }
        }
        
        var results: [ReassembledMessage] = []
        for (ecu, frameLines) in ecuBuckets {
            if let msg = processECUStream(ecuHeader: ecu, lines: frameLines) {
                results.append(msg)
            }
        }
        
        return results
    }
    
    private static func processECUStream(ecuHeader: String, lines: [String]) -> ReassembledMessage? {
        var totalExpectedLength = 0
        var accumulatedPayload: [UInt8] = []
        var nextExpectedSequence = 1
        
        for line in lines {
            let bytes = parseHexBytes(line)
            guard !bytes.isEmpty else { continue }
            
            let frame = classifyFrame(bytes: bytes)
            switch frame {
            case .singleFrame(let length, let data):
                let actual = Array(data.prefix(length))
                return buildMessage(ecu: ecuHeader, bytes: actual)
                
            case .firstFrame(let totalLen, let data):
                totalExpectedLength = totalLen
                accumulatedPayload = data
                nextExpectedSequence = 1
                
            case .consecutiveFrame(let seq, let data):
                if seq == nextExpectedSequence {
                    accumulatedPayload.append(contentsOf: data)
                    nextExpectedSequence = (nextExpectedSequence + 1) % 16
                }
                
            case .raw(let data):
                accumulatedPayload.append(contentsOf: data)
            }
            
            if totalExpectedLength > 0 && accumulatedPayload.count >= totalExpectedLength {
                let finalBytes = Array(accumulatedPayload.prefix(totalExpectedLength))
                return buildMessage(ecu: ecuHeader, bytes: finalBytes)
            }
        }
        
        if !accumulatedPayload.isEmpty {
            return buildMessage(ecu: ecuHeader, bytes: accumulatedPayload)
        }
        
        return nil
    }
    
    private static func classifyFrame(bytes: [UInt8]) -> FrameType {
        guard !bytes.isEmpty else { return .raw(data: bytes) }
        
        let pci = bytes[0]
        let pciType = (pci & 0xF0) >> 4
        
        switch pciType {
        case 0x0: // Single Frame (SF)
            let len = Int(pci & 0x0F)
            return .singleFrame(length: len, data: Array(bytes.dropFirst()))
            
        case 0x1: // First Frame (FF)
            guard bytes.count >= 2 else { return .raw(data: bytes) }
            let totalLen = (Int(pci & 0x0F) << 8) | Int(bytes[1])
            return .firstFrame(totalLength: totalLen, data: Array(bytes.dropFirst(2)))
            
        case 0x2: // Consecutive Frame (CF)
            let seq = Int(pci & 0x0F)
            return .consecutiveFrame(sequence: seq, data: Array(bytes.dropFirst()))
            
        default:
            return .raw(data: bytes)
        }
    }
    
    private static func buildMessage(ecu: String, bytes: [UInt8]) -> ReassembledMessage? {
        guard !bytes.isEmpty else { return nil }
        let service = bytes[0]
        var pid: UInt8? = nil
        var payloadBytes = Array(bytes.dropFirst())
        
        // Mode 01 / 02 / 09 responses: Byte 0 = Service + 0x40 (e.g. 0x41, 0x49), Byte 1 = PID
        if (service == 0x41 || service == 0x42 || service == 0x49) && !payloadBytes.isEmpty {
            pid = payloadBytes[0]
            payloadBytes = Array(payloadBytes.dropFirst())
        }
        
        return ReassembledMessage(
            ecuHeader: ecu,
            service: service,
            pid: pid,
            payload: payloadBytes
        )
    }
    
    static func parseHexBytes(_ text: String) -> [UInt8] {
        let clean = text.replacingOccurrences(of: " ", with: "")
        var bytes: [UInt8] = []
        var index = clean.startIndex
        
        while index < clean.endIndex {
            let nextIndex = clean.index(index, offsetBy: 2, limitedBy: clean.endIndex) ?? clean.endIndex
            let sub = String(clean[index..<nextIndex])
            if let byte = UInt8(sub, radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }
        
        return bytes
    }
}
