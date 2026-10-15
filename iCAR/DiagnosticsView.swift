import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var obd: OBDManager
    @State private var showingAskAISheet = false
    @State private var showingClearConfirmation = false
    @State private var selectedDTC: DiagnosticCode? = nil
    
    // 0: All, 1: Permanent (0A), 2: Stored (03), 3: Pending (07)
    @State private var selectedFilter = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Apple Large Title Navigation Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Diagnostics")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Theme.nominal)
                                    .frame(width: 7, height: 7)
                                Text(vehicleSubtitle)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Apple Readiness Pill
                        if obd.hasCompletedScan {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(obd.readinessPassed == obd.readinessTotal ? Theme.nominal : Theme.warning)
                                Text("\(obd.readinessPassed)/\(obd.readinessTotal) Ready")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.surfaceElevated)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Theme.surfaceBorder, lineWidth: 1)
                            )
                        } else {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Theme.textMuted)
                                    .frame(width: 6, height: 6)
                                Text("Awaiting Scan")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textMuted)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.surfaceElevated)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Theme.surfaceBorder, lineWidth: 1)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 4)
                
                // MARK: - Hero Health Card (Apple Health / Fitness Style)
                VStack(spacing: 16) {
                    HStack(alignment: .center, spacing: 16) {
                        // Diagnostic Indicator Shield Ring
                        ZStack {
                            Circle()
                                .stroke(statusAccentColor.opacity(0.18), lineWidth: 6)
                                .frame(width: 58, height: 58)
                            
                            Image(systemName: obd.hasCompletedScan ? (totalFaultsCount == 0 ? "checkmark.shield.fill" : "exclamationmark.shield.fill") : "sparkle.magnifyingglass")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(statusAccentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(heroTitleText)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text(heroSubtitleText)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    
                    // Comprehensive Scan Button
                    Button {
                        appleHapticImpact()
                        obd.runQuickScan()
                    } label: {
                        HStack(spacing: 8) {
                            if obd.isScanning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.canvas))
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "bolt.badge.checkmark.fill")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            
                            Text(obd.isScanning ? obd.scanStatusText : (obd.hasCompletedScan ? "Re-Scan Vehicle" : "Scan Vehicle for Faults"))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Theme.champagne, Theme.champagne.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .foregroundColor(Theme.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Theme.champagne.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .disabled(obd.isScanning)
                    
                    if obd.isScanning {
                        ProgressView(value: obd.scanProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: Theme.champagne))
                            .animation(Theme.appleSpring, value: obd.scanProgress)
                    }
                }
                .frostedCard(cornerRadius: 22)
                
                // MARK: - Post-Scan vs Pre-Scan Content
                if obd.hasCompletedScan {
                    // MARK: - Apple Segmented Filter Picker
                    HStack(spacing: 6) {
                        AppleFilterTab(
                            title: "All",
                            count: totalFaultsCount,
                            isSelected: selectedFilter == 0
                        ) {
                            withAnimation(Theme.appleSpring) { selectedFilter = 0 }
                        }
                        
                        AppleFilterTab(
                            title: "Permanent",
                            count: obd.permanentDTCs.count,
                            badgeColor: Theme.critical,
                            isSelected: selectedFilter == 1
                        ) {
                            withAnimation(Theme.appleSpring) { selectedFilter = 1 }
                        }
                        
                        AppleFilterTab(
                            title: "Stored",
                            count: obd.storedDTCs.count,
                            badgeColor: Theme.warning,
                            isSelected: selectedFilter == 2
                        ) {
                            withAnimation(Theme.appleSpring) { selectedFilter = 2 }
                        }
                        
                        AppleFilterTab(
                            title: "Pending",
                            count: obd.pendingDTCs.count,
                            badgeColor: Theme.warning,
                            isSelected: selectedFilter == 3
                        ) {
                            withAnimation(Theme.appleSpring) { selectedFilter = 3 }
                        }
                    }
                    
                    // MARK: - Permanent Codes (Mode 0A) Apple Regulatory Callout
                    if (selectedFilter == 1 || selectedFilter == 0) && !obd.permanentDTCs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.critical)
                                Text("Permanent Faults Locked in EEPROM")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("CARB §1968.2")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.critical)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.critical.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            
                            Text("Mode 0A fault codes cannot be erased by diagnostic scanners or battery disconnects. They remain stored in vehicle non-volatile memory until physical repairs are completed and multiple drive cycles pass.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.critical.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Theme.critical.opacity(0.25), lineWidth: 1)
                        )
                    }
                    
                    // MARK: - Grouped Fault Codes List (Apple Inset Style)
                    VStack(spacing: 10) {
                        let activeList = filteredDTCList
                        
                        if activeList.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(Theme.nominal)
                                Text(emptyFilterTitle)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("No diagnostic trouble codes logged by the electronic control units for this category.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                            .frostedCard(cornerRadius: 20)
                        } else {
                            ForEach(activeList) { dtc in
                                Button {
                                    appleHapticImpact()
                                    selectedDTC = dtc
                                } label: {
                                    HStack(spacing: 14) {
                                        // Status Badge Icon
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(dtc.isPermanent ? Theme.critical.opacity(0.15) : (dtc.severity == .critical ? Theme.critical.opacity(0.15) : Theme.warning.opacity(0.15)))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: dtc.isPermanent ? "lock.fill" : (dtc.severity == .critical ? "exclamationmark.triangle.fill" : "clock.fill"))
                                                .font(.system(size: 18))
                                                .foregroundColor(dtc.isPermanent ? Theme.critical : (dtc.severity == .critical ? Theme.critical : Theme.warning))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text(dtc.id)
                                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                                    .foregroundColor(Theme.textPrimary)
                                                
                                                Text(dtc.status.uppercased())
                                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                                    .foregroundColor(dtc.isPermanent ? Theme.critical : Theme.champagne)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(dtc.isPermanent ? Theme.critical.opacity(0.12) : Theme.surfaceElevated)
                                                    .clipShape(Capsule())
                                            }
                                            
                                            Text(dtc.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Theme.textPrimary)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(1)
                                            
                                            Text(dtc.system)
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Theme.textMuted)
                                    }
                                    .padding(14)
                                    .frostedCard(cornerRadius: 18)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                } else {
                    // MARK: - Pre-Scan Unscanned State (Apple Guide View)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.champagne.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.champagne)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Awaiting Diagnostic Scan")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Tap 'Scan Vehicle for Faults' above to interrogate ECU memory.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        
                        Divider().background(Theme.surfaceBorder)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("WHAT THIS SCAN INTERROGATES:")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.champagne)
                            
                            InspectionBullet(
                                icon: "lock.shield.fill",
                                color: Theme.critical,
                                title: "Mode 0A: Permanent Faults",
                                subtitle: "Non-volatile EEPROM codes mandated by CARB §1968.2 & EPA that cannot be cleared by reset tools."
                            )
                            
                            InspectionBullet(
                                icon: "exclamationmark.octagon.fill",
                                color: Theme.critical,
                                title: "Mode 03: Confirmed Stored Faults",
                                subtitle: "Active emissions & powertrain faults currently triggering the Check Engine Light."
                            )
                            
                            InspectionBullet(
                                icon: "clock.badge.exclamationmark.fill",
                                color: Theme.warning,
                                title: "Mode 07: Pending Faults",
                                subtitle: "Intermittent fault events logged during current or previous vehicle drive cycle."
                            )
                            
                            InspectionBullet(
                                icon: "chart.line.uptrend.xyaxis",
                                color: Theme.champagne,
                                title: "Mode 02: Freeze Frame Snapshots",
                                subtitle: "Engine operating telemetry latched at the exact microsecond each fault tripped."
                            )
                        }
                    }
                    .padding(18)
                    .frostedCard(cornerRadius: 20)
                }
                
                // MARK: - Action Buttons (Ask AI & Clear) - Only Post-Scan
                if obd.hasCompletedScan {
                    VStack(spacing: 12) {
                        // Apple Intelligence Style Action Button
                        Button {
                            appleHapticImpact()
                            showingAskAISheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15))
                                    .foregroundColor(Theme.champagne)
                                Text("Ask AI Diagnostic Specialist")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.champagne.opacity(0.35), lineWidth: 1)
                            )
                        }
                        
                        if !obd.storedDTCs.isEmpty || !obd.pendingDTCs.isEmpty {
                            Button {
                                appleHapticImpact()
                                showingClearConfirmation = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Clear Diagnostic Memory (Mode 04)")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(Theme.critical)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 16)
        }
        .sheet(item: $selectedDTC) { dtc in
            AppleDTCDetailSheet(dtc: dtc)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAskAISheet) {
            AppleAskAISheet(obd: obd)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Clear Diagnostic Trouble Codes?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Codes", role: .destructive) {
                appleHapticSuccess()
                obd.clearDTCs()
            }
        } message: {
            Text("Mode 04 resets stored and pending ECU error memory. Permanent (Mode 0A) codes are protected by EPA regulations and cannot be cleared by this tool.")
        }
    }
    
    // MARK: - Computed Properties
    private var totalFaultsCount: Int {
        obd.storedDTCs.count + obd.pendingDTCs.count + obd.permanentDTCs.count
    }
    
    private var vehicleSubtitle: String {
        if case .connected(let profile) = obd.connectionState {
            return "\(profile.year) \(profile.make) \(profile.model) · \(String(format: "%.1fV", profile.restingVoltage))"
        }
        return "Connected Vehicle"
    }
    
    private var heroTitleText: String {
        if !obd.hasCompletedScan {
            return "Scan Required"
        }
        if totalFaultsCount == 0 {
            return "System Clear"
        } else {
            return "\(totalFaultsCount) Faults Detected"
        }
    }
    
    private var statusAccentColor: Color {
        if !obd.hasCompletedScan {
            return Theme.champagne
        }
        if totalFaultsCount == 0 {
            return Theme.nominal
        } else if !obd.permanentDTCs.isEmpty || !obd.storedDTCs.isEmpty {
            return Theme.critical
        } else {
            return Theme.warning
        }
    }
    
    private var heroSubtitleText: String {
        if !obd.hasCompletedScan {
            return "Tap below to scan ECU memory for active and permanent trouble codes."
        }
        if totalFaultsCount == 0 {
            return "No ECU trouble codes detected across Mode 03, 07, and 0A."
        }
        var parts: [String] = []
        if !obd.permanentDTCs.isEmpty {
            parts.append("\(obd.permanentDTCs.count) Permanent")
        }
        if !obd.storedDTCs.isEmpty {
            parts.append("\(obd.storedDTCs.count) Stored")
        }
        if !obd.pendingDTCs.isEmpty {
            parts.append("\(obd.pendingDTCs.count) Pending")
        }
        return parts.joined(separator: " · ") + " codes require attention."
    }
    
    private var filteredDTCList: [DiagnosticCode] {
        switch selectedFilter {
        case 0:
            return obd.permanentDTCs + obd.storedDTCs + obd.pendingDTCs
        case 1:
            return obd.permanentDTCs
        case 2:
            return obd.storedDTCs
        case 3:
            return obd.pendingDTCs
        default:
            return obd.permanentDTCs + obd.storedDTCs + obd.pendingDTCs
        }
    }
    
    private var emptyFilterTitle: String {
        switch selectedFilter {
        case 1: return "No Permanent Faults"
        case 2: return "No Stored Faults"
        case 3: return "No Pending Faults"
        default: return "No Fault Codes Logged"
        }
    }
}

// MARK: - Apple Filter Segment Button
struct AppleFilterTab: View {
    let title: String
    let count: Int
    var badgeColor: Color = Theme.champagne
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? Theme.canvas : Theme.textPrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Theme.champagne : Theme.surfaceElevated)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.surfaceElevated : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Theme.surfaceBorder : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Apple DTC Detail Sheet (Apple Health Record Style)
struct AppleDTCDetailSheet: View {
    let dtc: DiagnosticCode
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header Title Card
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(dtc.isPermanent ? Theme.critical.opacity(0.18) : Theme.warning.opacity(0.18))
                                    .frame(width: 52, height: 52)
                                Image(systemName: dtc.isPermanent ? "lock.shield.fill" : "exclamationmark.octagon.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(dtc.isPermanent ? Theme.critical : Theme.warning)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dtc.id)
                                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                                Text(dtc.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .frostedCard(cornerRadius: 20)
                        
                        // Permanent Code Regulatory Warning (CARB / EPA)
                        if dtc.isPermanent {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(Theme.critical)
                                    Text("Mode 0A Non-Erasable Status")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.critical)
                                }
                                
                                Text("Mandated under California CARB §1968.2 and US EPA Clean Air Act. This permanent fault is anchored in ECU non-volatile memory. Diagnostic reset tools cannot erase it.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineSpacing(3)
                                
                                if let criteria = dtc.driveCycleResolution {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("REQUIRED DRIVE CYCLE RESOLUTION:")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(Theme.champagne)
                                        Text(criteria)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                    .padding(10)
                                    .background(Theme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Theme.critical.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Theme.critical.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // SAE Official Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SAE OFFICIAL DESCRIPTION")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.champagne)
                            Text(dtc.saeDescription)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .frostedCard(cornerRadius: 18)
                        
                        // Possible Causes
                        if !dtc.commonCauses.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("LIKELY ROOT CAUSES")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.champagne)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(dtc.commonCauses, id: \.self) { cause in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "wrench.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.champagne)
                                                .padding(.top, 2)
                                            Text(cause)
                                                .font(.system(size: 13))
                                                .foregroundColor(Theme.textPrimary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .frostedCard(cornerRadius: 18)
                        }
                        
                        // Mode 02 Freeze Frame Snapshot
                        if !dtc.freezeFrame.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("MODE 02 FREEZE FRAME DATA")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.champagne)
                                    Spacer()
                                    Text("Recorded at Fault")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                VStack(spacing: 8) {
                                    ForEach(Array(dtc.freezeFrame.keys.sorted()), id: \.self) { key in
                                        HStack {
                                            Text(key)
                                                .font(.system(size: 13))
                                                .foregroundColor(Theme.textSecondary)
                                            Spacer()
                                            Text(dtc.freezeFrame[key] ?? "-")
                                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                .foregroundColor(Theme.textPrimary)
                                        }
                                        if key != Array(dtc.freezeFrame.keys.sorted()).last {
                                            Divider().background(Theme.surfaceBorder)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .frostedCard(cornerRadius: 18)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Fault Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.champagne)
                }
            }
        }
    }
}

// MARK: - Apple Ask AI Sheet (Apple Intelligence Style)
struct AppleAskAISheet: View {
    @ObservedObject var obd: OBDManager
    @Environment(\.dismiss) var dismiss
    @State private var copied = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Theme.champagne, Theme.warning],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.canvas)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Diagnostic Intelligence")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Local-First Privacy · Anonymized VIN")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(16)
                        .frostedCard(cornerRadius: 18)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SYNTHESIZED DIAGNOSTIC PROMPT")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.champagne)
                            
                            Text(obd.buildAskAIPrompt())
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Theme.textPrimary)
                                .lineSpacing(3)
                                .padding(14)
                                .background(Theme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(16)
                        .frostedCard(cornerRadius: 18)
                        
                        Button {
                            UIPasteboard.general.string = obd.buildAskAIPrompt()
                            copied = true
                            appleHapticSuccess()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                                Text(copied ? "Copied Diagnostic Prompt" : "Copy Prompt for Claude / Gemini")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.champagne)
                            .foregroundColor(Theme.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("AI Mechanic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.champagne)
                }
            }
        }
    }
}

// MARK: - Pre-Scan Inspection Bullet
struct InspectionBullet: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 3)
    }
}
