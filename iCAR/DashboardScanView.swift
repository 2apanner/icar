import SwiftUI

struct DashboardScanView: View {
    @ObservedObject var obd: OBDManager
    @State private var isPulsing = false
    let onScanFinished: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Vehicle Overview Header
                if case .connected(let profile) = obd.connectionState {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("\(String(profile.year)) \(profile.model)")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Circle()
                                        .fill(Theme.nominal)
                                        .frame(width: 8, height: 8)
                                }
                                
                                Text(profile.engine)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("BATTERY")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textMuted)
                                
                                Text(String(format: "%.1f V", obd.liveTelemetry.batteryVoltage > 0 ? obd.liveTelemetry.batteryVoltage : profile.restingVoltage))
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.nominal)
                            }
                        }
                        
                        Divider().background(Theme.surfaceBorder)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Text("VIN:")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textMuted)
                                Text(profile.maskedVIN)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("BUS:")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textMuted)
                                Text("CAN 500k")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                    }
                    .padding(18)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.surfaceBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                
                // MARK: - Central SCAN CAR Action Hero
                VStack(spacing: 20) {
                    ZStack {
                        // Outer Pulsing Rings
                        if obd.isScanning {
                            Circle()
                                .stroke(Theme.accent.opacity(0.15), lineWidth: 2)
                                .frame(width: 190, height: 190)
                                .scaleEffect(isPulsing ? 1.25 : 0.95)
                                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                            
                            Circle()
                                .stroke(Theme.accent.opacity(0.3), lineWidth: 2)
                                .frame(width: 155, height: 155)
                                .scaleEffect(isPulsing ? 1.15 : 0.98)
                                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                        }
                        
                        // Main Action Button
                        Button {
                            appleHapticImpact()
                            obd.runQuickScan()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Theme.accent, Color(red: 0x14 / 255.0, green: 0x4E / 255.0, blue: 0xA0 / 255.0)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 130, height: 130)
                                    .shadow(color: Theme.accent.opacity(0.35), radius: 18, x: 0, y: 8)
                                
                                VStack(spacing: 6) {
                                    if obd.isScanning {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.3)
                                        Text("\(Int(obd.scanProgress * 100))%")
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "stethoscope")
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("SCAN CAR")
                                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                                            .foregroundColor(.white)
                                            .tracking(0.8)
                                    }
                                }
                            }
                        }
                        .disabled(obd.isScanning)
                    }
                    .frame(height: 200)
                    .onAppear {
                        isPulsing = true
                    }
                    
                    VStack(spacing: 8) {
                        Text(obd.isScanning ? "Scanning Vehicle Systems..." : "Full Vehicle Diagnostics")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text(obd.isScanning ? obd.scanStatusText : "Tap 'SCAN CAR' to interrogate Mode 03, Mode 07, and Mode 0A DTCs across all electronic control units.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                // MARK: - Systems Monitored Pre-Scan Checklist
                VStack(alignment: .leading, spacing: 12) {
                    Text("CONTROL UNITS READY FOR SCAN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 8) {
                        ChecklistRow(title: "DME", subtitle: "Digital Motor Electronics · S58 Management", icon: "engine.combustion")
                        ChecklistRow(title: "EGS", subtitle: "Electronic Transmission Control · 8-Speed", icon: "gearshape.2")
                        ChecklistRow(title: "DSC", subtitle: "Dynamic Stability Control · ABS & Traction", icon: "car.side")
                        ChecklistRow(title: "BDC", subtitle: "Body Domain Controller · Power Distribution", icon: "lightbulb")
                        ChecklistRow(title: "KOMBI", subtitle: "Instrument Cluster · Live Telemetry", icon: "speedometer")
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer(minLength: 20)
            }
        }
        .onChange(of: obd.hasCompletedScan) { _, completed in
            if completed {
                appleHapticSuccess()
                onScanFinished()
            }
        }
    }
}

struct ChecklistRow: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.surfaceElevated)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(Theme.nominal)
                    .frame(width: 6, height: 6)
                Text("Ready")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.nominal)
            }
        }
        .padding(10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.surfaceBorder, lineWidth: 1)
        )
    }
}
