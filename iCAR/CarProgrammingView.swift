import SwiftUI

struct CarProgrammingView: View {
    @ObservedObject var obd: OBDManager
    @State private var showingRestoreAlert = false
    
    var body: some View {
        let safety = obd.checkCodingSafetyInterlock()
        
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Car Functions & Coding")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Comfort timers, lighting durations & body electronics customization")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Dynamic Safety Interlock Status Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: safety.isSafe ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.system(size: 18))
                            .foregroundColor(safety.isSafe ? Theme.nominal : Theme.warning)
                        
                        Text(safety.isSafe ? "SAFE CONFIGURATION ACTIVE · ZERO FLASH RISK" : "SAFETY INTERLOCK ACTIVE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(safety.isSafe ? Theme.nominal : Theme.warning)
                        
                        Spacer()
                    }
                    
                    Text(safety.isSafe ? "Battery potential (\(String(format: "%.1f", safety.currentVoltage))V ≥ 12.4V) is stable. Engine is OFF. DME/DDE engine maps and DSC braking controllers are isolated and read-only." : (safety.reason ?? "Safety guard prevents writing to vehicle modules."))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(2)
                }
                .padding(14)
                .background(safety.isSafe ? Theme.surface : Theme.warning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(safety.isSafe ? Theme.nominal.opacity(0.3) : Theme.warning, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                
                // OEM Factory Restore Action Banner
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OEM FACTORY RESTORE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                        Text("Revert all comfort settings to original factory baseline")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        appleHapticImpact()
                        showingRestoreAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("Restore")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(!safety.isSafe || obd.isCodingBusy)
                    .opacity(!safety.isSafe || obd.isCodingBusy ? 0.5 : 1.0)
                }
                .padding(14)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.surfaceBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                
                // Status Overlay if applying change
                if obd.isCodingBusy {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                        Text(obd.codingStatusMessage)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
                
                // Section 1: Toggle Parameters
                let toggles = obd.codingItems.filter { $0.isToggle }
                if !toggles.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.2.square")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.accent)
                            Text("VEHICLE BEHAVIOR FUNCTIONS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 8) {
                            ForEach(toggles) { item in
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill((item.currentValue == "Enabled" || item.currentValue.contains("Active")) ? Theme.accent.opacity(0.12) : Theme.surfaceElevated)
                                            .frame(width: 34, height: 34)
                                        Image(systemName: item.icon)
                                            .font(.system(size: 15))
                                            .foregroundColor((item.currentValue == "Enabled" || item.currentValue.contains("Active")) ? Theme.accent : Theme.textSecondary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                        Text(item.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                    
                                    let isChecked = item.currentValue == "Enabled" || item.currentValue.contains("Active")
                                    Toggle("", isOn: Binding(
                                        get: { isChecked },
                                        set: { newVal in
                                            appleHapticImpact()
                                            let targetVal = if item.options.count == 2 {
                                                newVal ? item.options[1] : item.options[0]
                                            } else {
                                                newVal ? "Enabled" : "Disabled"
                                            }
                                            obd.applyVehicleCoding(item: item, newValue: targetVal)
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(Theme.accent)
                                    .disabled(!safety.isSafe || obd.isCodingBusy)
                                }
                                .padding(12)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Theme.surfaceBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // Section 2: Timer & Multi-Option Parameters
                let selectors = obd.codingItems.filter { !$0.isToggle }
                if !selectors.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "timer")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.accent)
                            Text("CONVENIENCE TIMERS & THRESHOLDS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 8) {
                            ForEach(selectors) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Theme.accent.opacity(0.12))
                                                .frame(width: 34, height: 34)
                                            Image(systemName: item.icon)
                                                .font(.system(size: 15))
                                                .foregroundColor(Theme.accent)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Theme.textPrimary)
                                            Text(item.description)
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.textSecondary)
                                                .lineLimit(2)
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    HStack {
                                        Text("CURRENT VALUE:")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(Theme.textMuted)
                                        
                                        Spacer()
                                        
                                        Menu {
                                            ForEach(item.options, id: \.self) { opt in
                                                Button(opt) {
                                                    appleHapticImpact()
                                                    obd.applyVehicleCoding(item: item, newValue: opt)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(item.currentValue)
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(Theme.accent)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(Theme.accent)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Theme.surfaceElevated)
                                            .cornerRadius(6)
                                        }
                                        .disabled(!safety.isSafe || obd.isCodingBusy)
                                    }
                                    .padding(.top, 2)
                                }
                                .padding(12)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Theme.surfaceBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 30)
        }
        .alert("Restore Factory Defaults?", isPresented: $showingRestoreAlert) {
            Button("Yes, Restore Baseline", role: .destructive) {
                appleHapticSuccess()
                obd.restoreFactoryCoding()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will rewrite all vehicle comfort parameters back to original OEM factory specification. Drivetrain and safety computers are unaffected.")
        }
    }
}
