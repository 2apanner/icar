import SwiftUI

/// BimmerLink Inspired Clean Sensor Values View
struct LiveDataView: View {
    @ObservedObject var obd: OBDManager
    @State private var viewMode = 0 // 0: Dashboard Grid, 1: Scope
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sensor Values")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text("CAN Bus Streaming · 15 Hz Polling Rate")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.nominal)
                            .frame(width: 7, height: 7)
                        Text("Live")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.nominal)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.nominal.opacity(0.12))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // MARK: - Segmented Mode Switcher
                HStack(spacing: 6) {
                    Button {
                        appleHapticImpact()
                        withAnimation(Theme.appleSpring) { viewMode = 0 }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.2x2.fill")
                            Text("Dashboard")
                        }
                        .font(.system(size: 13, weight: viewMode == 0 ? .bold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewMode == 0 ? Theme.surfaceElevated : Color.clear)
                        .foregroundColor(viewMode == 0 ? Theme.textPrimary : Theme.textSecondary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        appleHapticImpact()
                        withAnimation(Theme.appleSpring) { viewMode = 1 }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.path.ecg")
                            Text("Oscilloscope")
                        }
                        .font(.system(size: 13, weight: viewMode == 1 ? .bold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewMode == 1 ? Theme.surfaceElevated : Color.clear)
                        .foregroundColor(viewMode == 1 ? Theme.textPrimary : Theme.textSecondary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(4)
                .background(Theme.surface)
                .cornerRadius(10)
                .padding(.horizontal, 16)
                
                if viewMode == 0 {
                    // MARK: - BimmerLink Clean Sensor Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        BimmerSensorTile(
                            title: "Engine Speed",
                            value: "\(Int(obd.liveTelemetry.rpm))",
                            unit: "RPM",
                            icon: "engine.combustion.fill",
                            progress: min(1.0, obd.liveTelemetry.rpm / 7000.0),
                            color: Theme.accent
                        )
                        
                        BimmerSensorTile(
                            title: "Vehicle Speed",
                            value: "\(Int(obd.liveTelemetry.speedKmh))",
                            unit: "km/h",
                            icon: "speedometer",
                            progress: min(1.0, obd.liveTelemetry.speedKmh / 260.0),
                            color: Theme.accent
                        )
                        
                        BimmerSensorTile(
                            title: "Coolant Temp",
                            value: "\(Int(obd.liveTelemetry.coolantTempC))",
                            unit: "°C",
                            icon: "thermometer.medium",
                            progress: min(1.0, obd.liveTelemetry.coolantTempC / 120.0),
                            color: obd.liveTelemetry.coolantTempC > 105 ? Theme.critical : Theme.accent
                        )
                        
                        BimmerSensorTile(
                            title: "Engine Oil Temp",
                            value: "\(Int(obd.liveTelemetry.oilTempC))",
                            unit: "°C",
                            icon: "drop.fill",
                            progress: min(1.0, obd.liveTelemetry.oilTempC / 130.0),
                            color: obd.liveTelemetry.oilTempC > 115 ? Theme.critical : Theme.accent
                        )
                        
                        BimmerSensorTile(
                            title: "Battery Voltage",
                            value: String(format: "%.1f", obd.liveTelemetry.batteryVoltage),
                            unit: "V",
                            icon: "battery.100.bolt",
                            progress: min(1.0, (obd.liveTelemetry.batteryVoltage - 10.0) / 5.0),
                            color: obd.liveTelemetry.batteryVoltage < 11.8 ? Theme.critical : Theme.nominal
                        )
                        
                        BimmerSensorTile(
                            title: "Boost Pressure",
                            value: String(format: "%.2f", max(0, obd.liveTelemetry.boostPsi / 14.5)),
                            unit: "bar",
                            icon: "gauge.with.needle.fill",
                            progress: min(1.0, max(0, obd.liveTelemetry.boostPsi / 22.0)),
                            color: obd.liveTelemetry.boostPsi > 18 ? Theme.warning : Theme.accent
                        )
                        
                        BimmerSensorTile(
                            title: "Intake Air Temp",
                            value: "\(Int(obd.liveTelemetry.intakeAirTempC))",
                            unit: "°C",
                            icon: "wind",
                            progress: min(1.0, obd.liveTelemetry.intakeAirTempC / 60.0),
                            color: Theme.accent
                        )
                        
                        BimmerSensorTile(
                            title: "Throttle Position",
                            value: "\(Int(obd.liveTelemetry.throttlePercent))",
                            unit: "%",
                            icon: "bolt.fill",
                            progress: min(1.0, obd.liveTelemetry.throttlePercent / 100.0),
                            color: Theme.accent
                        )
                    }
                    .padding(.horizontal, 16)
                    
                } else {
                    // MARK: - Digital Oscilloscope View
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("DUAL TRACE (RPM & BOOST)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Button {
                                obd.isOscilloscopeFrozen.toggle()
                            } label: {
                                Text(obd.isOscilloscopeFrozen ? "RESUME" : "HOLD")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.surfaceElevated)
                                    .cornerRadius(6)
                            }
                        }
                        
                        BimmerScopeCanvas(history: obd.oscilloscopeHistory)
                            .frame(height: 200)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.surfaceBorder, lineWidth: 1)
                            )
                        
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Circle().fill(Theme.accent).frame(width: 8, height: 8)
                                Text("RPM: \(Int(obd.liveTelemetry.rpm))")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            HStack(spacing: 6) {
                                Circle().fill(Theme.warning).frame(width: 8, height: 8)
                                Text("Boost: \(String(format: "%.1f", obd.liveTelemetry.boostPsi)) PSI")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Theme.surface)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Bimmer Sensor Tile (Clean & Legible)
struct BimmerSensorTile: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let progress: Double
    var color: Color = Theme.accent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            
            // Clean Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.surfaceElevated)
                        .frame(height: 3)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.surfaceBorder, lineWidth: 1)
        )
    }
}

// MARK: - Scope Canvas
struct BimmerScopeCanvas: View {
    let history: [(time: Double, rpm: Double, boost: Double)]
    
    var body: some View {
        Canvas { context, size in
            guard history.count > 1 else { return }
            
            // Draw grid
            var gridPath = Path()
            for y in stride(from: 0.0, to: size.height, by: size.height / 4.0) {
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(gridPath, with: .color(Theme.surfaceBorder.opacity(0.5)), lineWidth: 0.5)
            
            // Draw RPM (Blue)
            var rpmPath = Path()
            for (idx, pt) in history.enumerated() {
                let x = (CGFloat(idx) / CGFloat(max(1, history.count - 1))) * size.width
                let norm = CGFloat(pt.rpm / 7000.0)
                let y = size.height - (norm * size.height)
                if idx == 0 {
                    rpmPath.move(to: CGPoint(x: x, y: y))
                } else {
                    rpmPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(rpmPath, with: .color(Theme.accent), lineWidth: 1.5)
            
            // Draw Boost (Amber)
            var boostPath = Path()
            for (idx, pt) in history.enumerated() {
                let x = (CGFloat(idx) / CGFloat(max(1, history.count - 1))) * size.width
                let norm = CGFloat(pt.boost / 20.0)
                let y = size.height - (norm * size.height)
                if idx == 0 {
                    boostPath.move(to: CGPoint(x: x, y: y))
                } else {
                    boostPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(boostPath, with: .color(Theme.warning), lineWidth: 1.5)
        }
    }
}
