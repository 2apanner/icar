import SwiftUI

/// BimmerLink Inspired Clean Error Memory View
struct DiagnosticsView: View {
    @ObservedObject var obd: OBDManager
    @State private var selectedECU: ECUErrorEntry? = nil
    @State private var showingClearConfirm = false
    @State private var showingAskAISheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Header & Vehicle Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Error Memory")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text(vehicleSubtitle)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        if obd.hasCompletedScan {
                            Text(totalErrorsCount == 0 ? "0 Errors" : "\(totalErrorsCount) Errors")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(totalErrorsCount == 0 ? Theme.nominal : Theme.critical)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(totalErrorsCount == 0 ? Theme.nominal.opacity(0.12) : Theme.critical.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // MARK: - Vehicle Access Safety Guard
                let safety = obd.checkSafetyInterlock()
                HStack(spacing: 8) {
                    Image(systemName: safety.isSafe ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundColor(safety.isSafe ? Theme.nominal : Theme.warning)
                        .font(.system(size: 13))
                    
                    Text(safety.isSafe ? "SAFE PROTOCOL: Engine OFF · Ignition ON · \(String(format: "%.1f", obd.liveTelemetry.batteryVoltage))V" : (safety.isEngineRunning ? "SAFETY GUARD: Engine Running (\(Int(obd.liveTelemetry.rpm)) RPM) · Resets Protected" : "SAFETY GUARD: Low Battery (\(String(format: "%.1f", obd.liveTelemetry.batteryVoltage))V)"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(safety.isSafe ? Theme.textSecondary : Theme.warning)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(safety.isSafe ? Theme.surface : Theme.warning.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                
                // MARK: - Primary Action Bar (Read / Clear)
                HStack(spacing: 12) {
                    Button {
                        appleHapticImpact()
                        obd.runQuickScan()
                    } label: {
                        HStack(spacing: 8) {
                            if obd.isScanning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            
                            Text(obd.isScanning ? "Scanning..." : (obd.hasCompletedScan ? "Re-read Errors" : "Read Error Memory"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(obd.isScanning)
                    
                    if obd.hasCompletedScan && totalErrorsCount > 0 {
                        Button {
                            appleHapticImpact()
                            showingClearConfirm = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Clear")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.critical)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.surface)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.critical.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                if obd.isScanning {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: obd.scanProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: Theme.accent))
                        Text(obd.scanStatusText)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                }
                
                // MARK: - Error Memory Content
                if obd.hasCompletedScan {
                    // Summary Banner
                    HStack(spacing: 12) {
                        Image(systemName: totalErrorsCount == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(totalErrorsCount == 0 ? Theme.nominal : Theme.critical)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(totalErrorsCount == 0 ? "All Control Units Clear" : "\(totalErrorsCount) Faults in \(ecusWithErrorsCount) Control Unit(s)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text(totalErrorsCount == 0 ? "No error entries stored in vehicle memory." : "Tap an ECU below to inspect fault code details and freeze frames.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    // Permanent CARB Banner if applicable
                    if !obd.permanentDTCs.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(Theme.warning)
                                .font(.system(size: 16))
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Permanent Fault Codes (CARB §1968.2)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Permanent codes are locked in EEPROM until the fault is repaired and drive cycle self-tests pass.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(12)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                    
                    // Control Units Grouped List (BimmerLink Style)
                    VStack(spacing: 8) {
                        ForEach(obd.ecuList) { ecu in
                            Button {
                                appleHapticImpact()
                                selectedECU = ecu
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: iconForECU(ecu.code))
                                        .font(.system(size: 18))
                                        .foregroundColor(ecu.errorCount > 0 ? Theme.critical : Theme.accent)
                                        .frame(width: 32)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ecu.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Text("\(ecu.code) · \(ecu.system)")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Status Badge
                                    Text(ecu.errorCount == 0 ? "0 errors" : "\(ecu.errorCount) error\(ecu.errorCount > 1 ? "s" : "")")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(ecu.errorCount == 0 ? Theme.nominal : Theme.critical)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ecu.errorCount == 0 ? Theme.nominal.opacity(0.12) : Theme.critical.opacity(0.12))
                                        .cornerRadius(6)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.textMuted)
                                }
                                .padding(14)
                                .background(Theme.surface)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Ask AI Assistance Button
                    Button {
                        appleHapticImpact()
                        showingAskAISheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Diagnose with AI Specialist")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.surface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    
                } else {
                    // MARK: - Pre-Scan State
                    VStack(spacing: 16) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.accent)
                        
                        VStack(spacing: 4) {
                            Text("Error Memory Not Read")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text("Tap 'Read Error Memory' above to scan all control units for stored, pending, and permanent fault codes.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Divider().background(Theme.surfaceBorder)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CONTROL UNITS DETECTED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            
                            let previewECUs = ["DME (Digital Motor Electronics)", "EGS (Transmission Control)", "DSC (Dynamic Stability Control)", "BDC (Body Domain Controller)", "KOMBI (Instrument Cluster)"]
                            
                            ForEach(previewECUs, id: \.self) { name in
                                HStack {
                                    Circle()
                                        .fill(Theme.textMuted)
                                        .frame(width: 6, height: 6)
                                    Text(name)
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("Ready")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textMuted)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(20)
                    .background(Theme.surface)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .sheet(item: $selectedECU) { ecu in
            BimmerECUDetailSheet(ecu: ecu)
        }
        .sheet(isPresented: $showingAskAISheet) {
            BimmerAskAISheet(obd: obd)
        }
        .alert(obd.checkSafetyInterlock().isSafe ? "Clear Error Memory?" : "Safety Interlock Warning", isPresented: $showingClearConfirm) {
            Button("Cancel", role: .cancel) {}
            if obd.checkSafetyInterlock().isSafe {
                Button("Clear All", role: .destructive) {
                    appleHapticSuccess()
                    obd.clearDTCs()
                }
            } else {
                Button("Override & Clear", role: .destructive) {
                    appleHapticSuccess()
                    obd.clearDTCs(force: true)
                }
            }
        } message: {
            let safety = obd.checkSafetyInterlock()
            if safety.isSafe {
                Text("Mode 04 resets active error memory across all ECUs. Permanent CARB §1968.2 codes cannot be cleared manually and will reset after successful drive cycles.")
            } else {
                Text(safety.reason ?? "Safety conditions not optimal. To avoid engine stumbles or ECU communication brownout, ensure Engine is OFF, Ignition is ON, and battery is healthy.")
            }
        }
    }
    
    private var totalErrorsCount: Int {
        obd.storedDTCs.count + obd.pendingDTCs.count + obd.permanentDTCs.count
    }
    
    private var ecusWithErrorsCount: Int {
        obd.ecuList.filter { $0.errorCount > 0 }.count
    }
    
    private var vehicleSubtitle: String {
        if case .connected(let profile) = obd.connectionState {
            return "\(String(profile.year)) \(profile.make) \(profile.model) · \(profile.vin)"
        }
        return "Connected Vehicle"
    }
    
    private func iconForECU(_ code: String) -> String {
        switch code {
        case "DME": return "engine.combustion.fill"
        case "EGS": return "gearshape.2.fill"
        case "DSC": return "car.circle.fill"
        case "BDC": return "lightbulb.fill"
        case "KOMBI": return "gauge.with.needle.fill"
        case "IHKA": return "fanblades.fill"
        case "ACSM": return "shield.fill"
        default: return "cpu.fill"
        }
    }
}

// MARK: - ECU Detail Sheet
struct BimmerECUDetailSheet: View {
    let ecu: ECUErrorEntry
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // ECU Header
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.accent.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "cpu.fill")
                                    .foregroundColor(Theme.accent)
                                    .font(.system(size: 20))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ecu.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("\(ecu.code) · \(ecu.system)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(14)
                        .background(Theme.surface)
                        .cornerRadius(12)
                        
                        if ecu.errors.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.nominal)
                                Text("No Faults Logged")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("This control unit reported 0 trouble codes.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(Theme.surface)
                            .cornerRadius(12)
                        } else {
                            Text("LOGGED FAULT CODES (\(ecu.errors.count))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            
                            ForEach(ecu.errors) { dtc in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(dtc.id)
                                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Spacer()
                                        
                                        Text(dtc.status.uppercased())
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(dtc.isPermanent ? Theme.critical : Theme.accent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(dtc.isPermanent ? Theme.critical.opacity(0.12) : Theme.accent.opacity(0.12))
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(dtc.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text(dtc.saeDescription)
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    if !dtc.freezeFrame.isEmpty {
                                        Divider().background(Theme.surfaceBorder)
                                        
                                        Text("FREEZE FRAME TELEMETRY")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                        
                                        ForEach(Array(dtc.freezeFrame.keys.sorted()), id: \.self) { key in
                                            HStack {
                                                Text(key)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Theme.textSecondary)
                                                Spacer()
                                                Text(dtc.freezeFrame[key] ?? "-")
                                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                    .foregroundColor(Theme.textPrimary)
                                            }
                                        }
                                    }
                                }
                                .padding(14)
                                .background(Theme.surface)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(ecu.code)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }
}

// MARK: - Ask AI Sheet
struct BimmerAskAISheet: View {
    let obd: OBDManager
    @Environment(\.dismiss) var dismiss
    @State private var copied = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DIAGNOSTIC PROMPT FOR LLM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.accent)
                        
                        Text(obd.buildAskAIPrompt())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .padding(14)
                            .background(Theme.surface)
                            .cornerRadius(12)
                        
                        Button {
                            UIPasteboard.general.string = obd.buildAskAIPrompt()
                            copied = true
                            appleHapticSuccess()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied to Clipboard" : "Copy Prompt for AI")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.accent)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Diagnostic AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }
}
