import SwiftUI

/// Screen 1: Clean On-Demand Bluetooth Discovery & Connection Hub
/// No static clutter: User taps "Search & Connect OBD-II", nearby BLE adapters are discovered dynamically.
struct ConnectionView: View {
    @ObservedObject var obd: OBDManager
    @State private var isRadarPulsing = false
    
    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Brand Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.18))
                                .frame(width: 96, height: 96)
                                .blur(radius: 20)
                            
                            Image("iCARLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Theme.surfaceBorder, lineWidth: 1.5)
                                )
                                .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 6)
                        }
                        .padding(.top, 24)
                        
                        VStack(spacing: 4) {
                            Text("iCAR")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                                .tracking(1.5)
                            
                            Text("Intelligent Connected Automotive Reader")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Theme.nominal)
                                .frame(width: 6, height: 6)
                            Text("BLUETOOTH 5.0 LE · CLOUD TELEMATICS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(6)
                    }
                    
                    // MARK: - Main Search / Connect Action
                    if !obd.isSearching && obd.discoveredAdapters.isEmpty {
                        // IDLE STATE: Primary "Search & Connect" Hero Button
                        VStack(spacing: 18) {
                            Button {
                                obd.startBLESearch()
                            } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Search & Connect OBD-II")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("Scan for nearby Bluetooth adapters")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.85))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.white.opacity(0.8))
                                }
                                .padding(18)
                                .background(
                                    LinearGradient(
                                        colors: [Theme.accent, Color(red: 0x14 / 255.0, green: 0x4E / 255.0, blue: 0xA0 / 255.0)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: Theme.accent.opacity(0.35), radius: 14, x: 0, y: 7)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 16)
                            
                            // 3-Step Setup Instructions Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("HOW TO CONNECT")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textMuted)
                                
                                ConnectionStepRow(number: "1", title: "Plug in Adapter", detail: "Connect your OBD-II Bluetooth adapter to the 16-pin port under the driver dashboard.")
                                ConnectionStepRow(number: "2", title: "Ignition ON", detail: "Turn vehicle ignition to position 2 (engine OFF or running).")
                                ConnectionStepRow(number: "3", title: "Tap Search", detail: "Press Search above to pair via BLE and read your vehicle's VIN.")
                            }
                            .padding(16)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.surfaceBorder, lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                            
                            // Simulator / Bench Test Mode
                            Button {
                                obd.connectSimulator()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 13))
                                    Text("Test with Virtual BMW M3 Simulator")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Theme.surfaceElevated)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Theme.surfaceBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 4)
                        }
                    } else {
                        // SEARCHING / DISCOVERED STATE
                        VStack(spacing: 16) {
                            // Animated Radar Status Card
                            VStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .stroke(Theme.accent.opacity(0.2), lineWidth: 2)
                                        .frame(width: 80, height: 80)
                                        .scaleEffect(isRadarPulsing ? 1.4 : 1.0)
                                        .opacity(isRadarPulsing ? 0 : 0.8)
                                    
                                    Circle()
                                        .fill(Theme.accent.opacity(0.15))
                                        .frame(width: 64, height: 64)
                                    
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundColor(Theme.accent)
                                }
                                .onAppear {
                                    withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                                        isRadarPulsing = true
                                    }
                                }
                                
                                VStack(spacing: 4) {
                                    Text(obd.isSearching ? "Searching for OBD-II Devices..." : "Discovered Devices")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text(obd.isSearching ? "Bring your phone near the adapter under the dash" : "Select your adapter to establish connection")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                HStack(spacing: 12) {
                                    if obd.isSearching {
                                        Button {
                                            obd.stopBLESearch()
                                        } label: {
                                            Text("Stop Search")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(Theme.critical)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 6)
                                                .background(Theme.critical.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                    } else {
                                        Button {
                                            obd.startBLESearch()
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.system(size: 11))
                                                Text("Scan Again")
                                                    .font(.system(size: 12, weight: .semibold))
                                            }
                                            .foregroundColor(Theme.accent)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                            .background(Theme.surfaceElevated)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Theme.surfaceBorder, lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                            
                            // Discovered Devices List
                            if !obd.discoveredAdapters.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("SELECT YOUR ADAPTER")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(Theme.textMuted)
                                        .padding(.horizontal, 4)
                                    
                                    VStack(spacing: 10) {
                                        ForEach(obd.discoveredAdapters) { adapter in
                                            Button {
                                                appleHapticImpact()
                                                obd.connect(to: adapter)
                                            } label: {
                                                HStack(spacing: 14) {
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(Theme.accent.opacity(0.15))
                                                            .frame(width: 44, height: 44)
                                                        
                                                        Image(systemName: adapter.kind.iconName)
                                                            .font(.system(size: 18))
                                                            .foregroundColor(Theme.accent)
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        HStack(spacing: 6) {
                                                            Text(adapter.name)
                                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                                .foregroundColor(Theme.textPrimary)
                                                            
                                                            if adapter.isRecommended {
                                                                Text("COMPATIBLE")
                                                                    .font(.system(size: 8, weight: .bold))
                                                                    .foregroundColor(Theme.nominal)
                                                                    .padding(.horizontal, 5)
                                                                    .padding(.vertical, 1)
                                                                    .background(Theme.nominal.opacity(0.15))
                                                                    .cornerRadius(4)
                                                            }
                                                        }
                                                        
                                                        Text(adapter.detail)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(Theme.textSecondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    HStack(spacing: 8) {
                                                        Image(systemName: "cellularbars", variableValue: adapter.rssi > -60 ? 1.0 : (adapter.rssi > -75 ? 0.75 : 0.5))
                                                            .font(.system(size: 12))
                                                            .foregroundColor(Theme.nominal)
                                                        
                                                        Text("Connect")
                                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 14)
                                                            .padding(.vertical, 7)
                                                            .background(Theme.accent)
                                                            .clipShape(Capsule())
                                                    }
                                                }
                                                .padding(14)
                                                .background(Theme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .stroke(adapter.isRecommended ? Theme.accent.opacity(0.5) : Theme.surfaceBorder, lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // MARK: - Connecting Modal Overlay
                    if case .connecting(let step) = obd.connectionState {
                        VStack(spacing: 14) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                                .scaleEffect(1.2)
                            
                            VStack(spacing: 4) {
                                Text("Connecting to Vehicle")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text(step)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button {
                                obd.disconnect()
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.textMuted)
                                    .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Theme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer(minLength: 30)
                }
            }
        }
    }
}

private struct ConnectionStepRow: View {
    let number: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceElevated)
                    .frame(width: 24, height: 24)
                Text(number)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(1.5)
            }
        }
    }
}
