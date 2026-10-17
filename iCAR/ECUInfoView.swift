import SwiftUI

/// Deep ECU Identity, Software Versions (CALID / CVN), Diagnostic History & Smog Readiness
struct ECUInfoView: View {
    @ObservedObject var obd: OBDManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("ECU Intelligence & Readiness")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Mode 09 CALID / CVN cryptographic verification, mileage history & I/M smog status")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Section 1: ECU Firmware & Identification
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.accent)
                        Text("ECU HARDWARE & CALIBRATION")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    VStack(spacing: 8) {
                        ECUDetailRow(label: "MODULE NAME", value: obd.deepECUInfo.ecuName)
                        Divider().background(Theme.surfaceBorder)
                        ECUDetailRow(label: "CALIBRATION ID (CALID)", value: obd.deepECUInfo.calibrationId)
                        Divider().background(Theme.surfaceBorder)
                        ECUDetailRow(label: "CVN FLASH CHECKSUM", value: obd.deepECUInfo.calibrationVerificationNumber)
                        Divider().background(Theme.surfaceBorder)
                        if case .connected(let profile) = obd.connectionState {
                            ECUDetailRow(label: "LOCKED BUS PROTOCOL", value: profile.protocolName)
                        } else {
                            ECUDetailRow(label: "LOCKED BUS PROTOCOL", value: "ISO 15765-4 (CAN 11/500)")
                        }
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.surfaceBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                
                // Section 2: Diagnostic Timers & Mileage History
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.accent)
                        Text("DIAGNOSTIC HISTORY & MILEAGE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    VStack(spacing: 8) {
                        ECUDetailRow(
                            label: "CHECK ENGINE (MIL) LAMP",
                            value: obd.deepECUInfo.isMILActive ? "ACTIVE (CHECK ENGINE ON)" : "OFF (NOMINAL)"
                        )
                        Divider().background(Theme.surfaceBorder)
                        
                        let distMIL = obd.deepECUInfo.distanceWithMILKm
                        ECUDetailRow(
                            label: "DISTANCE WITH MIL ON",
                            value: distMIL != nil ? "\(Int(distMIL!)) km (\(String(format: "%.1f", distMIL! * 0.621371)) mi)" : "Not Reported by ECU"
                        )
                        Divider().background(Theme.surfaceBorder)
                        
                        let distClr = obd.deepECUInfo.distanceSinceDTCClearedKm
                        ECUDetailRow(
                            label: "DISTANCE SINCE DTCs CLEARED",
                            value: distClr != nil ? "\(Int(distClr!)) km (\(String(format: "%.1f", distClr! * 0.621371)) mi)" : "Not Reported by ECU"
                        )
                        Divider().background(Theme.surfaceBorder)
                        
                        let warmups = obd.deepECUInfo.warmupsSinceDTCCleared
                        ECUDetailRow(
                            label: "WARMUPS SINCE DTCs CLEARED",
                            value: warmups != nil ? "\(warmups!) drive cycles" : "Not Reported by ECU"
                        )
                        Divider().background(Theme.surfaceBorder)
                        
                        let runTime = obd.deepECUInfo.engineRunTimeSeconds
                        ECUDetailRow(
                            label: "ENGINE RUN TIME",
                            value: runTime != nil ? "\(runTime! / 60) min \(runTime! % 60) sec" : "Not Reported by ECU"
                        )
                        Divider().background(Theme.surfaceBorder)
                        
                        let volt = obd.deepECUInfo.controlModuleVoltage
                        ECUDetailRow(
                            label: "ECU INTERNAL POTENTIAL",
                            value: volt != nil ? String(format: "%.2f V", volt!) : String(format: "%.2f V", obd.liveTelemetry.batteryVoltage)
                        )
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.surfaceBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                
                // Section 3: I/M Readiness Monitors Breakdown
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.nominal)
                        Text("EMISSIONS / SMOG READINESS MONITORS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        
                        Text("\(obd.readinessPassed)/\(obd.readinessTotal) Ready")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(obd.readinessPassed >= 7 ? Theme.nominal : Theme.warning)
                    }
                    .padding(.horizontal, 4)
                    
                    VStack(spacing: 6) {
                        if obd.deepECUInfo.smogMonitors.isEmpty {
                            Text("Run Quick Scan to retrieve ECU readiness monitors")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textMuted)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 14)
                        } else {
                            ForEach(obd.deepECUInfo.smogMonitors) { mon in
                                HStack {
                                    Text(mon.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    if !mon.isSupported {
                                        Text("NOT SUPPORTED")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(Theme.textMuted)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Theme.surfaceElevated)
                                            .clipShape(Capsule())
                                    } else if mon.isReady {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .black))
                                            Text("READY / PASSED")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        }
                                        .foregroundColor(Theme.nominal)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Theme.nominal.opacity(0.12))
                                        .clipShape(Capsule())
                                    } else {
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock.fill")
                                                .font(.system(size: 9))
                                            Text("INCOMPLETE")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        }
                                        .foregroundColor(Theme.warning)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Theme.warning.opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.surfaceBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
    }
}

private struct ECUDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}
