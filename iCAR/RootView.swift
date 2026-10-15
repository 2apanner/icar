import SwiftUI

struct RootView: View {
    @StateObject private var obd = OBDManager()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            
            switch obd.connectionState {
            case .disconnected, .scanning, .connecting, .error:
                ConnectionView(obd: obd)
                
            case .connected(let profile):
                VStack(spacing: 0) {
                    // MARK: - Apple Header Strip
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
                                Text("\(profile.year) \(profile.model)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                
                                HStack(spacing: 4) {
                                    Text(profile.protocolName)
                                    Text("·")
                                    Text(String(format: "%.1fV", profile.restingVoltage))
                                }
                                .font(.system(size: 11, design: .monospaced))
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
                            .foregroundColor(Theme.champagne)
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
                    
                    // MARK: - Main Tab Content
                    ZStack {
                        switch selectedTab {
                        case 0:
                            DiagnosticsView(obd: obd)
                        case 1:
                            LiveDataView(obd: obd)
                        case 2:
                            CodingServiceView(obd: obd)
                        case 3:
                            FlightRecorderView(obd: obd)
                        default:
                            DiagnosticsView(obd: obd)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // MARK: - Apple Translucent Floating Tab Bar
                    HStack(spacing: 0) {
                        AppleTabItem(
                            title: "Diagnostics",
                            icon: "stethoscope",
                            isSelected: selectedTab == 0
                        ) {
                            appleHapticImpact()
                            withAnimation(Theme.appleSpring) { selectedTab = 0 }
                        }
                        
                        AppleTabItem(
                            title: "Live Data",
                            icon: "gauge.with.needle.fill",
                            isSelected: selectedTab == 1
                        ) {
                            appleHapticImpact()
                            withAnimation(Theme.appleSpring) { selectedTab = 1 }
                        }
                        
                        AppleTabItem(
                            title: "Coding & Svc",
                            icon: "wrench.and.screwdriver.fill",
                            isSelected: selectedTab == 2
                        ) {
                            appleHapticImpact()
                            withAnimation(Theme.appleSpring) { selectedTab = 2 }
                        }
                        
                        AppleTabItem(
                            title: "Terminal",
                            icon: "terminal.fill",
                            isSelected: selectedTab == 3
                        ) {
                            appleHapticImpact()
                            withAnimation(Theme.appleSpring) { selectedTab = 3 }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 22)
                    .background(.ultraThinMaterial)
                    .overlay(
                        Divider().background(Theme.surfaceBorder), alignment: .top
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
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
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.champagne : Theme.textSecondary)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Theme.champagne : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
