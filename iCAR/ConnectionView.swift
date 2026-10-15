import SwiftUI

struct ConnectionView: View {
    @ObservedObject var obd: OBDManager
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Theme.accent.opacity(isPulsing ? 0.08 : 0.3), lineWidth: 1.5)
                                .frame(width: isPulsing ? 120 : 80, height: isPulsing ? 120 : 80)
                                .scaleEffect(isPulsing ? 1.15 : 0.95)
                            
                            Circle()
                                .fill(Theme.surfaceElevated)
                                .frame(width: 68, height: 68)
                                .overlay(
                                    Circle().stroke(Theme.surfaceBorder, lineWidth: 1)
                                )
                                .shadow(color: Theme.accent.opacity(0.18), radius: 10, x: 0, y: 4)
                            
                            Image(systemName: "bolt.car.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(Theme.accent)
                        }
                        .padding(.top, 24)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                                isPulsing = true
                            }
                        }
                        
                        VStack(spacing: 6) {
                            Text("Connect Adapter")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Insert adapter into 16-pin OBD-II port & switch ignition ON.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                    }
                    
                    // MARK: - Adapter Kind Segmented Control
                    HStack(spacing: 4) {
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
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(obd.selectedTransport == kind ? Theme.surfaceElevated : Color.clear)
                                )
                                .foregroundColor(obd.selectedTransport == kind ? Theme.textPrimary : Theme.textMuted)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(4)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.surfaceBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    
                    // MARK: - Direct Connect Demo Card
                    Button {
                        appleHapticImpact()
                        if let demo = obd.discoveredAdapters.first(where: { $0.kind == .demo }) {
                            obd.connect(to: demo)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.accent.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "bolt.car.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.accent)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("Virtual BMW M3 (G80)")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text("SIMULATOR")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(Theme.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.accentSubtle)
                                        .clipShape(Capsule())
                                }
                                
                                Text("Real CAN Bus protocol simulation: DME fault memory, live telemetry, CBS reset.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            Text("Connect")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Theme.accent)
                                .clipShape(Capsule())
                        }
                        .padding(14)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.surfaceBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    
                    // MARK: - Discovered Hardware Adapters Section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("DISCOVERED ADAPTERS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                                .tracking(0.5)
                            
                            Spacer()
                            
                            HStack(spacing: 5) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                                    .scaleEffect(0.65)
                                Text("Scanning")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 8) {
                            ForEach(filteredAdapters) { adapter in
                                Button {
                                    appleHapticImpact()
                                    obd.connect(to: adapter)
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(adapter.isRecommended ? Theme.accent.opacity(0.15) : Theme.surfaceElevated)
                                                .frame(width: 40, height: 40)
                                            
                                            Image(systemName: adapter.kind.iconName)
                                                .font(.system(size: 16))
                                                .foregroundColor(adapter.isRecommended ? Theme.accent : Theme.textSecondary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 5) {
                                                Text(adapter.name)
                                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                    .foregroundColor(Theme.textPrimary)
                                                    .lineLimit(1)
                                                
                                                if adapter.isRecommended {
                                                    Text("RECOMMENDED")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundColor(Theme.accent)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Theme.accentSubtle)
                                                        .cornerRadius(3)
                                                }
                                            }
                                            
                                            Text(adapter.detail)
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 8) {
                                            Image(systemName: "cellularbars", variableValue: adapter.rssi > -60 ? 1.0 : (adapter.rssi > -75 ? 0.75 : 0.5))
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.nominal)
                                            
                                            Text("Connect")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(Color.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Theme.accent)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(12)
                                    .background(Theme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Theme.surfaceBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // MARK: - Connecting Modal Overlay
                    if case .connecting(let step) = obd.connectionState {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                                .scaleEffect(1.1)
                            
                            Text(step)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(Theme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
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
