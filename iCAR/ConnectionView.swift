import SwiftUI

struct ConnectionView: View {
    @ObservedObject var obd: OBDManager
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Apple AirDrop / AirPods Style Radar Header
                    VStack(spacing: 16) {
                        ZStack {
                            // Pulsing radar circles
                            Circle()
                                .stroke(Theme.champagne.opacity(isPulsing ? 0.05 : 0.25), lineWidth: 1.5)
                                .frame(width: isPulsing ? 130 : 80, height: isPulsing ? 130 : 80)
                                .scaleEffect(isPulsing ? 1.2 : 0.9)
                            
                            Circle()
                                .stroke(Theme.champagne.opacity(isPulsing ? 0.1 : 0.4), lineWidth: 1.5)
                                .frame(width: 90, height: 90)
                            
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.surfaceElevated, Theme.surface],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 68, height: 68)
                                .overlay(
                                    Circle().stroke(Theme.glassBorderGradient, lineWidth: 1)
                                )
                                .shadow(color: Theme.champagne.opacity(0.15), radius: 12, x: 0, y: 4)
                            
                            Image(systemName: "bolt.car.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(Theme.champagne)
                        }
                        .padding(.top, 20)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                isPulsing = true
                            }
                        }
                        
                        VStack(spacing: 6) {
                            Text("Connect to Vehicle")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Plug adapter into the 16-pin OBD-II port under steering column and turn ignition ON.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    
                    // MARK: - Apple Segmented Picker
                    HStack(spacing: 6) {
                        ForEach(TransportKind.allCases) { kind in
                            Button {
                                appleHapticImpact()
                                withAnimation(Theme.appleSpring) {
                                    obd.selectedTransport = kind
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: kind.iconName)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(kind.rawValue)
                                        .font(.system(size: 13, weight: obd.selectedTransport == kind ? .bold : .medium, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(obd.selectedTransport == kind ? Theme.surfaceElevated : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(obd.selectedTransport == kind ? Theme.surfaceBorder : Color.clear, lineWidth: 1)
                                )
                                .foregroundColor(obd.selectedTransport == kind ? Theme.textPrimary : Theme.textSecondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(4)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.surfaceBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // MARK: - Quick Test Bench Card (Apple Quick Start Card)
                    Button {
                        appleHapticImpact()
                        if let demo = obd.discoveredAdapters.first(where: { $0.kind == .demo }) {
                            obd.connect(to: demo)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.champagne.opacity(0.15))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "bolt.car.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.champagne)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("Virtual 2018 Golf GTI")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text("DEMO")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.canvas)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.champagne)
                                        .clipShape(Capsule())
                                }
                                
                                Text("High-fidelity test car with Mode 0A Permanent DTCs & Live Telemetry.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            Text("Connect")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.canvas)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Theme.champagne)
                                .clipShape(Capsule())
                        }
                        .padding(14)
                        .frostedCard(cornerRadius: 18)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    
                    // MARK: - Discovered Hardware Adapters Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("DISCOVERED ADAPTERS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.champagne)
                                .tracking(0.5)
                            
                            Spacer()
                            
                            HStack(spacing: 5) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.champagne))
                                    .scaleEffect(0.65)
                                Text("Scanning BLE")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 10) {
                            ForEach(filteredAdapters) { adapter in
                                Button {
                                    appleHapticImpact()
                                    obd.connect(to: adapter)
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(adapter.isRecommended ? Theme.champagne.opacity(0.15) : Theme.surfaceElevated)
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: adapter.kind.iconName)
                                                .font(.system(size: 18))
                                                .foregroundColor(adapter.isRecommended ? Theme.champagne : Theme.textSecondary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 5) {
                                                Text(adapter.name)
                                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                    .foregroundColor(Theme.textPrimary)
                                                    .lineLimit(1)
                                                
                                                if adapter.isRecommended {
                                                    Image(systemName: "star.fill")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(Theme.champagne)
                                                }
                                            }
                                            
                                            Text(adapter.detail)
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        // Signal Strength Meter & Connect Button
                                        HStack(spacing: 8) {
                                            Image(systemName: "cellularbars", variableValue: adapter.rssi > -60 ? 1.0 : (adapter.rssi > -75 ? 0.75 : 0.5))
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.nominal)
                                            
                                            Text("Connect")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(Theme.canvas)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Theme.champagne)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(14)
                                    .frostedCard(cornerRadius: 18)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - Connecting Modal Overlay
                    if case .connecting(let step) = obd.connectionState {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.champagne))
                                .scaleEffect(1.1)
                            
                            Text(step)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Theme.champagne.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 30)
                }
            }
        }
    }
    
    private var filteredAdapters: [DiscoveredAdapter] {
        obd.discoveredAdapters.filter { adapter in
            switch obd.selectedTransport {
            case .bluetooth: return adapter.kind == .bluetooth
            case .wifi: return adapter.kind == .wifi
            case .demo: return adapter.kind == .demo
            }
        }
    }
}
