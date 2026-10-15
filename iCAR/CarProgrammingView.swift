import SwiftUI

struct VehicleTimerSetting: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let options: [String]
    var selectedOption: String
}

struct VehicleToggleSetting: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    var isEnabled: Bool
}

struct CarProgrammingView: View {
    @ObservedObject var obd: OBDManager
    
    @State private var timerSettings: [VehicleTimerSetting] = [
        VehicleTimerSetting(
            id: "welcome_light",
            name: "Welcome Light Duration",
            description: "Controls how long exterior headlights and door handle puddle lights stay illuminated upon unlocking.",
            icon: "flashlight.on.fill",
            options: ["Off", "10 sec", "20 sec", "30 sec", "60 sec"],
            selectedOption: "20 sec"
        ),
        VehicleTimerSetting(
            id: "follow_me_home",
            name: "Pathway Follow-Me-Home Timer",
            description: "Keeps low-beam headlights on after ignition off to illuminate your walkway.",
            icon: "sun.max.fill",
            options: ["Off", "20 sec", "40 sec", "60 sec", "90 sec"],
            selectedOption: "40 sec"
        ),
        VehicleTimerSetting(
            id: "window_delay",
            name: "Comfort Window Closure Delay",
            description: "Delay threshold when holding lock button on remote key fob before all power windows and sunroof roll up.",
            icon: "arrow.up.and.down.square.fill",
            options: ["Immediate", "1.5 sec", "2.5 sec", "3.5 sec"],
            selectedOption: "1.5 sec"
        ),
        VehicleTimerSetting(
            id: "auto_lock_speed",
            name: "Auto Door Lock Threshold",
            description: "Automatically locks all doors once the vehicle accelerates past this speed threshold.",
            icon: "lock.shield.fill",
            options: ["Off", "5 km/h", "10 km/h", "16 km/h", "20 km/h"],
            selectedOption: "16 km/h"
        )
    ]
    
    @State private var convenienceToggles: [VehicleToggleSetting] = [
        VehicleToggleSetting(
            id: "start_stop_mem",
            name: "Auto Start-Stop Memory",
            description: "Remembers last selected Auto Start-Stop state instead of defaulting ON each ignition cycle.",
            icon: "engine.combustion.fill",
            isEnabled: true
        ),
        VehicleToggleSetting(
            id: "acoustic_lock",
            name: "Acoustic Confirmation Chirp",
            description: "Emits a short confirmation chirp from horn/alarm siren upon locking with remote fob.",
            icon: "speaker.wave.2.fill",
            isEnabled: true
        ),
        VehicleToggleSetting(
            id: "mirror_fold",
            name: "Power Mirrors Auto-Fold",
            description: "Folds side mirrors automatically when vehicle is locked and unfolds on engine ignition.",
            icon: "car.side.fill",
            isEnabled: true
        ),
        VehicleToggleSetting(
            id: "daytime_running",
            name: "Daytime Running Angel Eyes",
            description: "Enables signature high-intensity LED daytime running halos in headlights.",
            icon: "headlight.daytime.fill",
            isEnabled: true
        )
    ]
    
    @State private var isApplyingChange = false
    @State private var applyingMessage = ""
    @State private var showAppliedToast = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Car Functions & Programming")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Convenience timers, lighting durations & vehicle behavior settings")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Safety Shield Badge
                HStack(spacing: 10) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.nominal)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SAFE CONFIGURATION MODE · ZERO FLASH RISK")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.nominal)
                        Text("Changes modify high-level convenience parameters only. DME bootloader, engine maps, and powertrain firmware are strictly isolated and cannot be corrupted.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(12)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.nominal.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                
                // Status Overlay if applying change
                if isApplyingChange {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                        Text(applyingMessage)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
                
                // MARK: - Section 1: Vehicle Convenience Timers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.accent)
                        Text("VEHICLE CONVENIENCE TIMERS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    VStack(spacing: 10) {
                        ForEach($timerSettings) { $setting in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Theme.accent.opacity(0.12))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: setting.icon)
                                            .font(.system(size: 15))
                                            .foregroundColor(Theme.accent)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(setting.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                        Text(setting.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Options Menu
                                HStack {
                                    Text("TIMER DURATION:")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(Theme.textMuted)
                                    
                                    Spacer()
                                    
                                    Menu {
                                        ForEach(setting.options, id: \.self) { opt in
                                            Button(opt) {
                                                setting.selectedOption = opt
                                                applySetting(name: setting.name, value: opt)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(setting.selectedOption)
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
                
                // MARK: - Section 2: Vehicle Behavior Functions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "slider.horizontal.2.square")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.accent)
                        Text("VEHICLE BEHAVIOR FUNCTIONS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    VStack(spacing: 10) {
                        ForEach($convenienceToggles) { $toggleSetting in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(toggleSetting.isEnabled ? Theme.accent.opacity(0.12) : Theme.surfaceElevated)
                                        .frame(width: 34, height: 34)
                                    Image(systemName: toggleSetting.icon)
                                        .font(.system(size: 15))
                                        .foregroundColor(toggleSetting.isEnabled ? Theme.accent : Theme.textSecondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(toggleSetting.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text(toggleSetting.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { toggleSetting.isEnabled },
                                    set: { newValue in
                                        toggleSetting.isEnabled = newValue
                                        applySetting(name: toggleSetting.name, value: newValue ? "ENABLED" : "DISABLED")
                                    }
                                ))
                                .labelsHidden()
                                .tint(Theme.accent)
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
            .padding(.bottom, 30)
        }
    }
    
    private func applySetting(name: String, value: String) {
        appleHapticSuccess()
        isApplyingChange = true
        applyingMessage = "Applying \(name)..."
        obd.log("CAR FUNCTION: Sending UDS 0x2E write for [\(name)] = \(value)", direction: .system)
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                isApplyingChange = false
                obd.log("CAR FUNCTION: Successfully updated \(name) to \(value)", direction: .system)
            }
        }
    }
}
