import SwiftUI

struct CodingServiceView: View {
    @ObservedObject var obd: OBDManager
    @State private var showingServiceResetAlert = false
    @State private var serviceResetName = ""
    @State private var batteryType = "AGM 70Ah"
    @State private var showingBatteryRegistrationConfirm = false
    @State private var selectedSubTab = 0 // 0: BMW BimmerCode Studio, 1: Battery & Maintenance
    
    var body: some View {
        VStack(spacing: 0) {
            // Apple Sub-Tab Segmented Switcher
            HStack(spacing: 6) {
                Button {
                    appleHapticImpact()
                    withAnimation(Theme.appleSpring) { selectedSubTab = 0 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.badge.clock.fill")
                        Text("BMW Coding")
                    }
                    .font(.system(size: 13, weight: selectedSubTab == 0 ? .bold : .medium, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedSubTab == 0 ? Theme.surfaceElevated : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selectedSubTab == 0 ? Theme.surfaceBorder : Color.clear, lineWidth: 1)
                    )
                    .foregroundColor(selectedSubTab == 0 ? Theme.textPrimary : Theme.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button {
                    appleHapticImpact()
                    withAnimation(Theme.appleSpring) { selectedSubTab = 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                        Text("Battery & Service")
                    }
                    .font(.system(size: 13, weight: selectedSubTab == 1 ? .bold : .medium, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedSubTab == 1 ? Theme.surfaceElevated : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selectedSubTab == 1 ? Theme.surfaceBorder : Color.clear, lineWidth: 1)
                    )
                    .foregroundColor(selectedSubTab == 1 ? Theme.textPrimary : Theme.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(4)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.surfaceBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            if selectedSubTab == 0 {
                BMWCodingStudioView(obd: obd)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Section 1: 20 Hz Cranking Voltage Drop Test
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BATTERY & STARTER ANALYSIS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.champagne)
                            Text("High-Frequency 20 Hz Cranking Voltage Drop")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                    }
                    
                    // Waveform Display
                    ZStack {
                        CrankingWaveformCanvas(samples: obd.crankingSamples)
                            .frame(height: 120)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.surfaceBorder, lineWidth: 1)
                            )
                        
                        if obd.crankingSamples.isEmpty && !obd.isCrankingTestRunning {
                            VStack(spacing: 4) {
                                Image(systemName: "bolt.batteryblock.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.champagne.opacity(0.6))
                                Text("Tap 'Start Crank Test' then crank engine")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    
                    if let result = obd.crankingResult {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("MIN CRANK VOLTAGE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                Text("\(String(format: "%.1f", result.minVoltage))V")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(result.isHealthy ? Theme.nominal : Theme.critical)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CHARGING (ALT)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                Text("\(String(format: "%.1f", result.chargingVoltage))V")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.nominal)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("HEALTH STATUS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                Text(result.isHealthy ? "PASSED (>9.6V)" : "WEAK STARTER")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(result.isHealthy ? Theme.nominal : Theme.critical)
                            }
                        }
                        .padding(12)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(10)
                    }
                    
                    Button {
                        obd.runCrankingTest()
                    } label: {
                        HStack(spacing: 8) {
                            if obd.isCrankingTestRunning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.canvas))
                                Text("Capturing 20Hz Waveform...")
                                    .font(.system(size: 14, weight: .bold))
                            } else {
                                Image(systemName: "waveform.path.ecg")
                                Text("START CRANK DROP TEST")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.champagne)
                        .foregroundColor(Theme.canvas)
                        .cornerRadius(10)
                    }
                    .disabled(obd.isCrankingTestRunning)
                }
                .padding(16)
                .frostedCard(cornerRadius: 16)
                
                // Section 2: Battery Registration
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BATTERY REGISTRATION (BMS)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.champagne)
                            Text("Register New Battery Capacity & Chemistry")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                    }
                    
                    HStack {
                        Picker("Battery Spec", selection: $batteryType) {
                            Text("70Ah AGM").tag("AGM 70Ah")
                            Text("80Ah AGM").tag("AGM 80Ah")
                            Text("92Ah AGM").tag("AGM 92Ah")
                            Text("70Ah EFB").tag("EFB 70Ah")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Button {
                        showingBatteryRegistrationConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Register New \(batteryType) Battery")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.surface)
                        .foregroundColor(Theme.champagne)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.champagne.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
                .padding(16)
                .frostedCard(cornerRadius: 16)
                
                // Section 3: Service Interval Resets (CBS)
                VStack(alignment: .leading, spacing: 12) {
                    Text("SERVICE INTERVAL RESETS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.champagne)
                        .tracking(0.5)
                    
                    VStack(spacing: 8) {
                        ServiceResetRow(title: "Engine Oil Service", dueText: "Due in 1,200 km") {
                            serviceResetName = "Engine Oil"
                            showingServiceResetAlert = true
                        }
                        ServiceResetRow(title: "Front Brake Pads", dueText: "Nominal (34,000 km)") {
                            serviceResetName = "Front Brakes"
                            showingServiceResetAlert = true
                        }
                        ServiceResetRow(title: "Brake Fluid Inspection", dueText: "Due Oct 2026") {
                            serviceResetName = "Brake Fluid"
                            showingServiceResetAlert = true
                        }
                    }
                }
                
                // Section 4: Vehicle Personalization Tweaks
                VStack(alignment: .leading, spacing: 12) {
                    Text("VEHICLE PERSONALIZATION (UDS CODING)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.champagne)
                        .tracking(0.5)
                    
                    VStack(spacing: 8) {
                        ForEach(obd.codingTweaks) { tweak in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tweak.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text(tweak.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { tweak.isEnabled },
                                    set: { _ in obd.toggleCodingTweak(id: tweak.id) }
                                ))
                                .labelsHidden()
                                .tint(Theme.champagne)
                            }
                            .padding(14)
                            .frostedCard(cornerRadius: 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        }
        }
        .alert("Reset \(serviceResetName)?", isPresented: $showingServiceResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                obd.log("SERVICE: CBS Reset executed for \(serviceResetName)", direction: .system)
            }
        } message: {
            Text("This will write service reset parameters to the instrument cluster gateway.")
        }
        .alert("Register \(batteryType)?", isPresented: $showingBatteryRegistrationConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Register", role: .none) {
                obd.log("BATTERY: BMS registered new battery [\(batteryType)] via UDS 0x2E", direction: .system)
            }
        } message: {
            Text("Power management curves will recalibrate for a fresh battery installation.")
        }
    }
}

struct ServiceResetRow: View {
    let title: String
    let dueText: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(dueText)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button("Reset") {
                action()
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Theme.champagne)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.surfaceElevated)
            .cornerRadius(8)
        }
        .padding(14)
        .frostedCard(cornerRadius: 12)
    }
}

struct CrankingWaveformCanvas: View {
    let samples: [(timeMs: Double, voltage: Double)]
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // Reference voltage lines: 9.6V (Critical threshold) & 12.0V
            let yCritical = height - (CGFloat((9.6 - 8.0) / 7.0) * height)
            var critPath = Path()
            critPath.move(to: CGPoint(x: 0, y: yCritical))
            critPath.addLine(to: CGPoint(x: width, y: yCritical))
            context.stroke(critPath, with: .color(Theme.critical.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            
            guard samples.count > 1 else { return }
            
            let stepX = width / CGFloat(max(1, samples.count - 1))
            var wavePath = Path()
            
            for (idx, sample) in samples.enumerated() {
                let x = CGFloat(idx) * stepX
                // Map 8.0V - 15.0V to height
                let normalized = min(1.0, max(0.0, (sample.voltage - 8.0) / 7.0))
                let y = height - (CGFloat(normalized) * (height - 12) + 6)
                if idx == 0 {
                    wavePath.move(to: CGPoint(x: x, y: y))
                } else {
                    wavePath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(wavePath, with: .color(Theme.champagne), lineWidth: 2)
        }
    }
}
