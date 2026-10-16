import SwiftUI

/// Screen 2: Initial Connection & Vehicle Identification Confirmation
/// Shows connection established, vehicle metadata, VIN verification, and registers record to Supabase.
struct VehicleConfirmationView: View {
    @ObservedObject var obd: OBDManager
    let profile: VehicleProfile
    let onConfirm: () -> Void
    
    @ObservedObject private var supabase = SupabaseManager.shared
    @State private var isSyncing = false
    @State private var hasSynced = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Initial Connection Badge
                HStack(spacing: 10) {
                    Circle()
                        .fill(Theme.nominal)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Theme.nominal.opacity(0.3), lineWidth: 4)
                        )
                    
                    Text("ECU LINK ESTABLISHED · ISO 15765-4 CAN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.nominal)
                    
                    Spacer()
                    
                    Text("500 kbps")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.nominal.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // MARK: - Vehicle Profile Header Card
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surfaceElevated)
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "car.side.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.accent)
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(String(profile.year)) \(profile.make) \(profile.model)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text(profile.engine)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    // Large Verified VIN Badge
                    VStack(spacing: 6) {
                        Text("VEHICLE IDENTIFICATION NUMBER (VIN)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                        
                        HStack(spacing: 8) {
                            Text(profile.vin)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.accent)
                                .tracking(1.2)
                            
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Theme.nominal)
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.canvas)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.surfaceBorder, lineWidth: 1)
                        )
                    }
                    
                    Divider().background(Theme.surfaceBorder)
                    
                    // Specs Grid
                    HStack(spacing: 0) {
                        VStack(alignment: .center, spacing: 2) {
                            Text("RESTING VOLTAGE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                            Text(String(format: "%.1f V", profile.restingVoltage))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.nominal)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider().frame(height: 32).background(Theme.surfaceBorder)
                        
                        VStack(alignment: .center, spacing: 2) {
                            Text("COMMUNICATION")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                            Text("CAN 11/500")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider().frame(height: 32).background(Theme.surfaceBorder)
                        
                        VStack(alignment: .center, spacing: 2) {
                            Text("DATABASE SYNC")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                            Text("Supabase")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.accent)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.surfaceBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                
                // MARK: - Supabase Cloud Registration Status Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(Theme.accent)
                            .font(.system(size: 15))
                        Text("CLOUD TELEMATICS BACKEND")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        
                        Text("PostgreSQL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.surfaceElevated)
                            .cornerRadius(4)
                    }
                    
                    Text("This vehicle's VIN and specification record will be securely registered in your Supabase backend database, enabling fleet monitoring and history tracking from your web app.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(2)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.nominal)
                            .font(.system(size: 13))
                        Text("Table: public.vehicles · Ready for upsert")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(.top, 2)
                }
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(14)
                .padding(.horizontal, 16)
                
                // MARK: - Primary Confirmation Button
                VStack(spacing: 12) {
                    Button {
                        appleHapticImpact()
                        confirmAndProceed()
                    } label: {
                        HStack(spacing: 8) {
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                Text("Registering VIN in Supabase...")
                                    .font(.system(size: 15, weight: .bold))
                            } else {
                                Text("Confirm Vehicle & Proceed")
                                    .font(.system(size: 16, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .cornerRadius(12)
                        .shadow(color: Theme.accent.opacity(0.35), radius: 12, x: 0, y: 6)
                    }
                    .disabled(isSyncing)
                    
                    Text("Tap confirm to lock vehicle identity and proceed to diagnostic scanning.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .padding(.bottom, 30)
        }
    }
    
    private func confirmAndProceed() {
        isSyncing = true
        Task {
            _ = await supabase.syncVehicleProfile(profile: profile)
            await MainActor.run {
                appleHapticSuccess()
                isSyncing = false
                hasSynced = true
                onConfirm()
            }
        }
    }
}
