import SwiftUI

struct LiveDataView: View {
    @ObservedObject var obd: OBDManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Bus Refresh Rate Badge
                // Header Bus Refresh Rate Badge
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Telemetry")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text("15.2 Hz Bus Refresh · ISO 15765-4 CAN")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Theme.nominal)
                            .frame(width: 6, height: 6)
                        Text("Active Stream")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.nominal)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.surfaceElevated)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Theme.surfaceBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 4)
                
                // 240° Tachometer Sweep Gauge
                ZStack {
                    TachometerCanvas(
                        rpm: obd.liveTelemetry.rpm,
                        rpmPeak: obd.rpmPeak,
                        maxRpm: 8000.0,
                        redlineRpm: 6500.0
                    )
                    .frame(height: 250)
                    
                    VStack(spacing: 2) {
                        Spacer()
                            .frame(height: 40)
                        
                        Text("\(Int(obd.liveTelemetry.rpm))")
                            .font(.system(size: 46, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("RPM")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack(spacing: 8) {
                            Text("GEAR \(obd.liveTelemetry.currentGear)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.canvas)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.champagne)
                                .clipShape(Capsule())
                            
                            Text("TPS \(Int(obd.liveTelemetry.throttlePercent))%")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 4)
                        
                        Text("PEAK \(Int(obd.rpmPeak)) RPM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.warning)
                            .padding(.top, 2)
                    }
                }
                .padding(.vertical, 8)
                .frostedCard(cornerRadius: 22)
                
                // Quad Sensor Tiles
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SensorTile(
                        label: "Boost Pressure",
                        value: String(format: "%.1f", obd.liveTelemetry.boostPsi),
                        unit: "PSI",
                        subtext: "Peak: \(String(format: "%.1f", obd.boostPeak)) PSI",
                        accentColor: obd.liveTelemetry.boostPsi > 15 ? Theme.warning : Theme.champagne
                    )
                    
                    SensorTile(
                        label: "Coolant Temp",
                        value: "\(Int(obd.liveTelemetry.coolantTempC))",
                        unit: "°C",
                        subtext: "Target: 90°C Nominal",
                        accentColor: obd.liveTelemetry.coolantTempC > 105 ? Theme.critical : Theme.nominal
                    )
                    
                    SensorTile(
                        label: "Short-Term Trim",
                        value: String(format: "%+.1f", obd.liveTelemetry.stftBank1Percent),
                        unit: "%",
                        subtext: "Normal: ±10.0%",
                        accentColor: abs(obd.liveTelemetry.stftBank1Percent) > 15 ? Theme.warning : Theme.textPrimary
                    )
                    
                    SensorTile(
                        label: "Mass Air Flow",
                        value: String(format: "%.1f", obd.liveTelemetry.mafGps),
                        unit: "g/s",
                        subtext: "Speed: \(Int(obd.liveTelemetry.speedKmh)) km/h",
                        accentColor: Theme.champagne
                    )
                }
                
                // Rolling Dual-Trace Real-Time Oscilloscope
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dual-Trace Oscilloscope")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text("Real-Time RPM (Gold) vs Boost (Mint)")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            appleHapticImpact()
                            obd.isOscilloscopeFrozen.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: obd.isOscilloscopeFrozen ? "play.fill" : "pause.fill")
                                    .font(.system(size: 10))
                                Text(obd.isOscilloscopeFrozen ? "Resume" : "Freeze")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(obd.isOscilloscopeFrozen ? Theme.canvas : Theme.champagne)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(obd.isOscilloscopeFrozen ? Theme.champagne : Theme.surfaceElevated)
                            .clipShape(Capsule())
                        }
                    }
                    
                    OscilloscopeCanvas(history: obd.oscilloscopeHistory)
                        .frame(height: 140)
                        .background(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.surfaceBorder, lineWidth: 1)
                        )
                }
                .padding(16)
                .frostedCard(cornerRadius: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

struct SensorTile: View {
    let label: String
    let value: String
    let unit: String
    let subtext: String
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .tracking(0.3)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)
                
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Text(subtext)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frostedCard(cornerRadius: 14)
    }
}

struct TachometerCanvas: View {
    let rpm: Double
    let rpmPeak: Double
    let maxRpm: Double
    let redlineRpm: Double
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
            let radius = min(size.width, size.height) / 2 - 24
            let startAngle = Angle(degrees: 150)
            let endAngle = Angle(degrees: 390) // 240 degrees sweep
            let totalDegrees = 240.0
            
            // 1. Background Arc Track
            var trackPath = Path()
            trackPath.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            context.stroke(trackPath, with: .color(Color.white.opacity(0.1)), lineWidth: 12)
            
            // 2. Redline Zone Arc (6,500 - 8,000)
            let redlineFraction = (redlineRpm / maxRpm)
            let redlineStartDeg = 150.0 + (totalDegrees * redlineFraction)
            var redlinePath = Path()
            redlinePath.addArc(center: center, radius: radius, startAngle: Angle(degrees: redlineStartDeg), endAngle: endAngle, clockwise: false)
            context.stroke(redlinePath, with: .color(Theme.critical.opacity(0.8)), lineWidth: 12)
            
            // 3. Active RPM Arc
            let clampedRpm = min(max(0, rpm), maxRpm)
            let rpmFraction = clampedRpm / maxRpm
            let activeEndDeg = 150.0 + (totalDegrees * rpmFraction)
            var activePath = Path()
            activePath.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: Angle(degrees: activeEndDeg), clockwise: false)
            context.stroke(activePath, with: .color(clampedRpm >= redlineRpm ? Theme.critical : Theme.champagne), lineWidth: 12)
            
            // 4. Peak Tick Marker
            let peakFraction = min(max(0, rpmPeak), maxRpm) / maxRpm
            let peakRad = (150.0 + totalDegrees * peakFraction) * .pi / 180.0
            let p1 = CGPoint(x: center.x + (radius - 10) * cos(peakRad), y: center.y + (radius - 10) * sin(peakRad))
            let p2 = CGPoint(x: center.x + (radius + 10) * cos(peakRad), y: center.y + (radius + 10) * sin(peakRad))
            var peakPath = Path()
            peakPath.move(to: p1)
            peakPath.addLine(to: p2)
            context.stroke(peakPath, with: .color(Theme.warning), lineWidth: 3)
        }
    }
}

struct OscilloscopeCanvas: View {
    let history: [(time: Double, rpm: Double, boost: Double)]
    
    var body: some View {
        Canvas { context, size in
            guard history.count > 1 else { return }
            
            let width = size.width
            let height = size.height
            let stepX = width / CGFloat(max(1, history.count - 1))
            
            // Draw grid lines
            for i in 1...3 {
                let y = height * CGFloat(i) / 4.0
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.addLine(to: CGPoint(x: width, y: y))
                context.stroke(gridPath, with: .color(Color.white.opacity(0.06)), lineWidth: 1)
            }
            
            // RPM Path (Gold) scaled 0 - 7000
            var rpmPath = Path()
            for (idx, point) in history.enumerated() {
                let x = CGFloat(idx) * stepX
                let normalizedRpm = min(1.0, max(0.0, point.rpm / 7000.0))
                let y = height - (CGFloat(normalizedRpm) * (height - 16) + 8)
                if idx == 0 {
                    rpmPath.move(to: CGPoint(x: x, y: y))
                } else {
                    rpmPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(rpmPath, with: .color(Theme.champagne), lineWidth: 2)
            
            // Boost Path (Mint) scaled 0 - 20 PSI
            var boostPath = Path()
            for (idx, point) in history.enumerated() {
                let x = CGFloat(idx) * stepX
                let normalizedBoost = min(1.0, max(0.0, point.boost / 20.0))
                let y = height - (CGFloat(normalizedBoost) * (height - 16) + 8)
                if idx == 0 {
                    boostPath.move(to: CGPoint(x: x, y: y))
                } else {
                    boostPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(boostPath, with: .color(Theme.nominal), lineWidth: 1.5)
        }
    }
}
