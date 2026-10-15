import SwiftUI

struct ConnectionView: View {
    @ObservedObject var obd: OBDManager
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - iCAR Home Screen Brand Header
                    VStack(spacing: 12) {
                        ZStack {
                            // Subtle ambient glow
                            Circle()
                                .fill(Theme.accent.opacity(0.18))
                                .frame(width: 100, height: 100)
                                .blur(radius: 20)
                            
                            Image("iCARLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 84, height: 84)
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
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                                .tracking(1.5)
                            
                            Text("Intelligent Connected Automotive Reader")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    // MARK: - Direct Connect Action Hero
                    Button {
                        appleHapticImpact()
                        directConnectAction()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Direct Connect")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Auto-detect OBD-II interface & connect")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [Theme.accent, Color(red: 0x14 / 255.0, green: 0x4E / 255.0, blue: 0xA0 / 255.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Theme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    
                    // MARK: - Transport Kind Segmented Selector
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
                                                    Text("DEFAULT")
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
    
    private func directConnectAction() {
        // If an adapter is discovered under current transport, connect to it; otherwise connect to recommended or demo
        if let target = filteredAdapters.first(where: { $0.isRecommended }) ?? filteredAdapters.first ?? obd.discoveredAdapters.first {
            obd.connect(to: target)
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
