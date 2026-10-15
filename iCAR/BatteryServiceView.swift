import SwiftUI

/// Clean Battery & Condition Based Service View
struct BatteryServiceView: View {
    @ObservedObject var obd: OBDManager
    @State private var showingBatteryRegisterConfirm = false
    @State private var selectedNewBatteryType = "90 Ah AGM"
    @State private var showingResetAlert = false
    @State private var itemToReset: ServiceResetItem? = nil
    
    let batteryTypes = [
        "70 Ah AGM", "80 Ah AGM", "90 Ah AGM", "105 Ah AGM",
        "70 Ah Lead-Acid", "80 Ah Lead-Acid", "90 Ah Lead-Acid"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery & Service")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("12V Power Management & Condition Based Servicing")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // MARK: - Battery Status
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "battery.100.bolt")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.accent)
                        Text("12V BATTERY STATUS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STATE OF CHARGE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Text("\(obd.liveTelemetry.batterySOC)%")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.nominal)
                        }
                        
                        Divider().frame(height: 36).background(Theme.surfaceBorder)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("VOLTAGE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Text(String(format: "%.1f V", obd.liveTelemetry.batteryVoltage))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        Divider().frame(height: 36).background(Theme.surfaceBorder)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("REGISTERED TYPE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Text(obd.registeredBatteryType)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Divider().background(Theme.surfaceBorder)
                    
                    // Battery Registration Actions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BATTERY REPLACEMENT REGISTRATION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("Registering a replacement battery informs the DME power management to reset the charging histogram, ensuring correct alternator charging curve.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(2)
                        
                        HStack(spacing: 10) {
                            Button {
                                appleHapticImpact()
                                obd.registerBattery(type: obd.registeredBatteryType)
                            } label: {
                                Text("Register Same Capacity")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.accent)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            Menu {
                                ForEach(batteryTypes, id: \.self) { type in
                                    Button(type) {
                                        appleHapticSuccess()
                                        obd.registerBattery(type: type)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("Change Capacity")
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10))
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Theme.surfaceElevated)
                                .foregroundColor(Theme.textPrimary)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(14)
                .padding(.horizontal, 16)
                
                // MARK: - Condition Based Service (CBS) Resets
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.accent)
                        Text("CONDITION BASED SERVICE (CBS)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(obd.serviceItems) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(item.isDue ? Theme.critical : Theme.accent)
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text(item.statusText)
                                        .font(.system(size: 12))
                                        .foregroundColor(item.isDue ? Theme.critical : Theme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    appleHapticImpact()
                                    itemToReset = item
                                    showingResetAlert = true
                                } label: {
                                    Text("Reset")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Theme.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.surfaceElevated)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(12)
                            .background(Theme.surfaceElevated.opacity(0.5))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .alert("Reset Service Interval?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                if let item = itemToReset {
                    appleHapticSuccess()
                    obd.resetServiceItem(id: item.id)
                }
            }
        } message: {
            if let item = itemToReset {
                Text("This sends a UDS Routine Control command to reset the \(item.name) counter in the instrument cluster / kombi.")
            }
        }
    }
}
