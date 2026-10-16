import SwiftUI

struct RootView: View {
    @StateObject private var obd = OBDManager()
    @State private var showingFunctionHub: Bool = {
        return ProcessInfo.processInfo.arguments.contains("-showFunctions")
    }()
    @State private var isVehicleConfirmed: Bool = {
        return ProcessInfo.processInfo.arguments.contains("-autoScanDemo") || ProcessInfo.processInfo.arguments.contains("-showFunctions")
    }()
    @State private var selectedTab: Int = {
        if ProcessInfo.processInfo.arguments.contains("-tabSensors") { return 1 }
        if ProcessInfo.processInfo.arguments.contains("-tabBattery") { return 2 }
        if ProcessInfo.processInfo.arguments.contains("-tabCarFunctions") { return 3 }
        if ProcessInfo.processInfo.arguments.contains("-tabTerminal") { return 4 }
        return 0
    }()
    
    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            
            switch obd.connectionState {
            case .disconnected, .scanning, .connecting, .error:
                // SCREEN 1: HOME SCREEN (iCAR Logo + Search & Connect OBD-II)
                ConnectionView(obd: obd)
                    .onAppear {
                        isVehicleConfirmed = false
                    }
                
            case .connected(let profile):
                if !isVehicleConfirmed {
                    // SCREEN 2: INITIAL CONNECTION & VEHICLE VIN CONFIRMATION
                    VStack(spacing: 0) {
                        // Header with Disconnect option
                        HStack {
                            Text("VEHICLE VERIFICATION")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                            
                            Spacer()
                            
                            Button {
                                appleHapticImpact()
                                obd.disconnect()
                                isVehicleConfirmed = false
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "eject.fill")
                                        .font(.system(size: 9))
                                    Text("Disconnect")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(Theme.textMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.surfaceElevated)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        VehicleConfirmationView(obd: obd, profile: profile) {
                            withAnimation(Theme.appleSpring) {
                                isVehicleConfirmed = true
                            }
                        }
                    }
                    .transition(.opacity)
                } else if !obd.hasCompletedScan && !showingFunctionHub {
                    // SCREEN 3: VEHICLE DASHBOARD (Pre-scan state with SCAN CAR action)
                    VStack(spacing: 0) {
                        DashboardTopHeader(profile: profile, obd: obd)
                        
                        DashboardScanView(obd: obd) {
                            withAnimation(Theme.appleSpring) {
                                showingFunctionHub = true
                            }
                        }
                    }
                    .transition(.opacity)
                } else {
                    // SCREEN 4: ALL CAR FUNCTIONS (Unlocked Post-Scan)
                    VStack(spacing: 0) {
                        // Function Hub Top Navigation Bar
                        HStack(spacing: 12) {
                            Button {
                                appleHapticImpact()
                                withAnimation(Theme.appleSpring) {
                                    showingFunctionHub = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Dashboard")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.surfaceElevated)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Theme.surfaceBorder, lineWidth: 1)
                                )
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Text("\(String(profile.year)) \(profile.model)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                                Text("·")
                                    .foregroundColor(Theme.textMuted)
                                Text(String(format: "%.1fV", obd.liveTelemetry.batteryVoltage > 0 ? obd.liveTelemetry.batteryVoltage : profile.restingVoltage))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.nominal)
                            }
                            
                            Spacer()
                            
                            Button {
                                appleHapticImpact()
                                withAnimation(Theme.appleSpring) {
                                    obd.disconnect()
                                    showingFunctionHub = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "eject.fill")
                                        .font(.system(size: 9))
                                    Text("Disconnect")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(Theme.textMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Theme.surfaceElevated)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Theme.surfaceBorder, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.surface.opacity(0.95))
                        .overlay(
                            Divider().background(Theme.surfaceBorder), alignment: .bottom
                        )
                        
                        // MARK: - Post-Scan Functions Content
                        ZStack {
                            switch selectedTab {
                            case 0:
                                DiagnosticsView(obd: obd)
                            case 1:
                                LiveDataView(obd: obd)
                            case 2:
                                BatteryServiceView(obd: obd)
                            case 3:
                                CarProgrammingView(obd: obd)
                            case 4:
                                FlightRecorderView(obd: obd)
                            default:
                                DiagnosticsView(obd: obd)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // MARK: - Navigation Tab Bar
                        HStack(spacing: 0) {
                            AppleTabItem(
                                title: "Errors",
                                icon: "exclamationmark.triangle.fill",
                                isSelected: selectedTab == 0
                            ) {
                                appleHapticImpact()
                                withAnimation(Theme.appleSpring) { selectedTab = 0 }
                            }
                            
                            AppleTabItem(
                                title: "Sensors",
                                icon: "gauge.with.needle.fill",
                                isSelected: selectedTab == 1
                            ) {
                                appleHapticImpact()
                                withAnimation(Theme.appleSpring) { selectedTab = 1 }
                            }
                            
                            AppleTabItem(
                                title: "Battery & Svc",
                                icon: "battery.100.bolt",
                                isSelected: selectedTab == 2
                            ) {
                                appleHapticImpact()
                                withAnimation(Theme.appleSpring) { selectedTab = 2 }
                            }
                            
                            AppleTabItem(
                                title: "Car Functions",
                                icon: "slider.horizontal.2.square",
                                isSelected: selectedTab == 3
                            ) {
                                appleHapticImpact()
                                withAnimation(Theme.appleSpring) { selectedTab = 3 }
                            }
                            
                            AppleTabItem(
                                title: "Terminal",
                                icon: "terminal.fill",
                                isSelected: selectedTab == 4
                            ) {
                                appleHapticImpact()
                                withAnimation(Theme.appleSpring) { selectedTab = 4 }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 22)
                        .background(Theme.surface.opacity(0.95))
                        .overlay(
                            Divider().background(Theme.surfaceBorder), alignment: .top
                        )
                    }
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct DashboardTopHeader: View {
    let profile: VehicleProfile
    @ObservedObject var obd: OBDManager
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.nominal.opacity(0.2))
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Theme.nominal)
                        .frame(width: 7, height: 7)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(profile.year)) \(profile.model)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text(profile.protocolName)
                        Text("·")
                        Text(profile.vin)
                            .foregroundColor(Theme.accent)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Button {
                appleHapticImpact()
                withAnimation(Theme.appleSpring) {
                    obd.disconnect()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "eject.fill")
                        .font(.system(size: 9))
                    Text("Disconnect")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.surfaceElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Theme.surfaceBorder, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(
            Divider().background(Theme.surfaceBorder), alignment: .bottom
        )
    }
}

struct AppleTabItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Theme.accent : Theme.textMuted)
                
                Text(title)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Theme.accent : Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
