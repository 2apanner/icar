import Foundation
import Combine

/// Native Swift Supabase Client for Automotive Telematics & Diagnostics Sync
@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    enum SyncState: Equatable {
        case idle
        case syncing(String)
        case synced(Date)
        case offlineCached
        case failed(String)
    }
    
    @Published var syncState: SyncState = .idle
    @Published var lastSyncedVIN: String? = nil
    
    // Supabase Project Credentials (Extracted from D-Pilot ecosystem)
    let projectURL = "https://mhmsyfjhvvnaokzhizts.supabase.co"
    let anonKey = "sb_publishable__IZgEBiFNFGVEsdMMXLc9A_goCb_29t"
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Upsert Vehicle Record
    func syncVehicleProfile(profile: VehicleProfile) async -> Bool {
        syncState = .syncing("Registering VIN \(profile.vin) in Supabase...")
        
        guard let url = URL(string: "\(projectURL)/rest/v1/vehicles?on_conflict=vin") else {
            syncState = .failed("Invalid Supabase URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let payload: [String: Any] = [
            "vin": profile.vin,
            "make": profile.make,
            "model": profile.model,
            "year": profile.year,
            "engine": profile.engine,
            "bus_protocol": profile.protocolName,
            "resting_voltage": profile.restingVoltage,
            "last_scanned_at": ISO8601DateFormatter().string(from: Date()),
            "metadata": [
                "scanned_by": "iCAR Mobile iOS",
                "app_version": "1.0.0"
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (_, response) = try await session.data(for: request)
            
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                syncState = .synced(Date())
                lastSyncedVIN = profile.vin
                return true
            } else {
                // Save locally for offline sync
                cacheVehicleLocally(profile: profile)
                syncState = .offlineCached
                return true
            }
        } catch {
            cacheVehicleLocally(profile: profile)
            syncState = .offlineCached
            return true
        }
    }
    
    // MARK: - Upload Full Diagnostic Scan Report
    func uploadScanReport(
        profile: VehicleProfile,
        storedDTCs: [DiagnosticCode],
        pendingDTCs: [DiagnosticCode],
        permanentDTCs: [DiagnosticCode],
        readinessPassed: Int,
        readinessTotal: Int,
        batteryVoltage: Double,
        batterySOC: Int,
        batteryType: String,
        cbsItems: [ServiceResetItem],
        reportText: String
    ) async -> Bool {
        syncState = .syncing("Uploading diagnostic scan report to cloud...")
        
        guard let url = URL(string: "\(projectURL)/rest/v1/diagnostic_scans") else {
            syncState = .failed("Invalid Supabase URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        let allDTCs = (storedDTCs + pendingDTCs + permanentDTCs).map { dtc -> [String: Any] in
            return [
                "id": dtc.id,
                "title": dtc.title,
                "system": dtc.system,
                "status": dtc.status,
                "severity": dtc.severity.rawValue,
                "sae_description": dtc.saeDescription,
                "freeze_frame": dtc.freezeFrame
            ]
        }
        
        let cbsPayload = cbsItems.map { [
            "id": $0.id,
            "name": $0.name,
            "status": $0.statusText,
            "is_due": $0.isDue
        ]}
        
        let payload: [String: Any] = [
            "vin": profile.vin,
            "scan_timestamp": ISO8601DateFormatter().string(from: Date()),
            "total_faults_count": storedDTCs.count + pendingDTCs.count + permanentDTCs.count,
            "stored_dtcs_count": storedDTCs.count,
            "pending_dtcs_count": pendingDTCs.count,
            "permanent_dtcs_count": permanentDTCs.count,
            "readiness_passed": readinessPassed,
            "readiness_total": readinessTotal,
            "battery_voltage": batteryVoltage,
            "battery_soc": batterySOC,
            "registered_battery_type": batteryType,
            "dtcs": allDTCs,
            "cbs_intervals": cbsPayload,
            "full_report_text": reportText
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (_, response) = try await session.data(for: request)
            
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                syncState = .synced(Date())
                return true
            } else {
                cacheScanLocally(vin: profile.vin, payload: payload)
                syncState = .offlineCached
                return true
            }
        } catch {
            cacheScanLocally(vin: profile.vin, payload: payload)
            syncState = .offlineCached
            return true
        }
    }
    
    // MARK: - Offline Storage
    private func cacheVehicleLocally(profile: VehicleProfile) {
        let dict: [String: Any] = [
            "vin": profile.vin,
            "make": profile.make,
            "model": profile.model,
            "year": profile.year,
            "resting_voltage": profile.restingVoltage
        ]
        UserDefaults.standard.set(dict, forKey: "offline_cached_vehicle_\(profile.vin)")
    }
    
    private func cacheScanLocally(vin: String, payload: [String: Any]) {
        UserDefaults.standard.set(payload, forKey: "offline_cached_scan_\(vin)_\(Date().timeIntervalSince1970)")
    }
}
