import SwiftUI

struct FlightRecorderView: View {
    @ObservedObject var obd: OBDManager
    @State private var filterTX = true
    @State private var filterRX = true
    @State private var filterSYS = true
    
    var body: some View {
        VStack(spacing: 12) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FLIGHT TERMINAL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.champagne)
                    Text("Circular 500-Line Raw ASCII Stream")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    FilterPill(label: "TX", isSelected: $filterTX, color: Theme.champagne)
                    FilterPill(label: "RX", isSelected: $filterRX, color: Theme.nominal)
                    FilterPill(label: "SYS", isSelected: $filterSYS, color: Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Console Terminal Box
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLogs) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Theme.textMuted)
                                
                                Text(badgeText(for: entry.direction))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(badgeColor(for: entry.direction))
                                    .frame(width: 26)
                                
                                Text(entry.message)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.vertical, 2)
                            .id(entry.id)
                        }
                    }
                    .padding(12)
                }
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.surfaceBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .onChange(of: obd.flightLogs.count) { _, _ in
                    if let last = obd.flightLogs.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            
            // Action Bar
            HStack(spacing: 12) {
                ShareLink(item: formattedLogText) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Raw Flight Log")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.surfaceElevated)
                    .foregroundColor(Theme.champagne)
                    .cornerRadius(10)
                }
                
                Button {
                    obd.flightLogs.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.critical)
                        .padding(12)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    var filteredLogs: [FlightLogEntry] {
        obd.flightLogs.filter { entry in
            switch entry.direction {
            case .tx: return filterTX
            case .rx: return filterRX
            case .system: return filterSYS
            }
        }
    }
    
    var formattedLogText: String {
        obd.flightLogs.map {
            "[\($0.timestamp.formatted(date: .omitted, time: .standard))] \(badgeText(for: $0.direction)): \($0.message)"
        }.joined(separator: "\n")
    }
    
    func badgeText(for dir: FlightLogEntry.Direction) -> String {
        switch dir {
        case .tx: return "TX"
        case .rx: return "RX"
        case .system: return "SYS"
        }
    }
    
    func badgeColor(for dir: FlightLogEntry.Direction) -> Color {
        switch dir {
        case .tx: return Theme.champagne
        case .rx: return Theme.nominal
        case .system: return Theme.textSecondary
        }
    }
}

struct FilterPill: View {
    let label: String
    @Binding var isSelected: Bool
    let color: Color
    
    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isSelected ? Theme.canvas : Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? color : Theme.surfaceElevated)
                .cornerRadius(6)
        }
    }
}
