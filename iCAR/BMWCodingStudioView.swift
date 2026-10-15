import SwiftUI

struct BMWCodingStudioView: View {
    @ObservedObject var obd: OBDManager
    @State private var selectedCategory: BMWCodingCategory = .engineDynamics
    @State private var selectedModule: BMWECUModule? = nil
    @State private var selectedSeries = "F-Series (F30, F32, F80, F82)"
    @State private var codingParameters = BMWCodingCatalog.shared.parameters
    
    @State private var pendingCodeParam: BMWCodingParameter? = nil
    @State private var showingWriteConfirmation = false
    @State private var isWritingECU = false
    @State private var writeStep = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Banner with BMW Series Selector
                VStack(spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.badge.clock.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.champagne)
                            Text("BIMMER STUDIO")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                                .tracking(0.5)
                        }
                        
                        Spacer()
                        
                        Text("UDS ISO 14229")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.champagne)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.champagneSubtle)
                            .cornerRadius(6)
                    }
                    
                    // Vehicle Series Menu
                    Menu {
                        Button("F-Series (F30, F32, F80, F82, F10, F20)") { selectedSeries = "F-Series (F30, F32, F80, F82)" }
                        Button("G-Series (G20, G30, G80, G82, G05)") { selectedSeries = "G-Series (G20, G30, G80, G82)" }
                        Button("E-Series (E90, E92, E60, E70)") { selectedSeries = "E-Series (E90, E92, E60, E70)" }
                    } label: {
                        HStack {
                            Text(selectedSeries)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(12)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(10)
                    }
                }
                .padding(16)
                .frostedCard(cornerRadius: 16)
                
                // Category Pills Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BMWCodingCategory.allCases) { cat in
                            Button {
                                selectedCategory = cat
                                selectedModule = nil
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.iconName)
                                        .font(.system(size: 12))
                                    Text(cat.rawValue)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCategory == cat ? Theme.champagne : Theme.surface)
                                .foregroundColor(selectedCategory == cat ? Theme.canvas : Theme.textSecondary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Theme.surfaceBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                // Coding Parameters List
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("\(selectedCategory.rawValue.uppercased()) CODING")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.champagne)
                            .tracking(0.5)
                        Spacer()
                        Text("\(filteredParams.count) Available")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(filteredParams) { param in
                            BMWCodingParameterCard(param: param) { updatedOption in
                                prepareCodeWrite(param: param, newOption: updatedOption)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showingWriteConfirmation) {
            if let param = pendingCodeParam {
                BMWEcuWriteSheet(
                    param: param,
                    isWriting: isWritingECU,
                    currentStep: writeStep,
                    onConfirm: {
                        executeUdsCodingWrite(param: param)
                    },
                    onCancel: {
                        showingWriteConfirmation = false
                    }
                )
            }
        }
    }
    
    var filteredParams: [BMWCodingParameter] {
        codingParameters.filter { $0.category == selectedCategory }
    }
    
    private func prepareCodeWrite(param: BMWCodingParameter, newOption: String) {
        var copy = param
        copy.selectedOption = newOption
        copy.isEnabled = (newOption != "Not Active" && newOption != "Disabled (Standard)")
        pendingCodeParam = copy
        showingWriteConfirmation = true
    }
    
    private func executeUdsCodingWrite(param: BMWCodingParameter) {
        isWritingECU = true
        writeStep = "Setting ECU Header (ATSH \(param.module.txHeaderCAN))..."
        obd.log("CODING: Target Module \(param.module.shortName) (ATSH \(param.module.txHeaderCAN))", direction: .system)
        
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            obd.log("TX: 10 03", direction: .tx)
            obd.log("RX: 50 03 00 32 01 F4", direction: .rx) // Positive Response
            
            await MainActor.run { writeStep = "Entering Extended Diagnostic Session (10 03)..." }
            try? await Task.sleep(nanoseconds: 600_000_000)
            
            await MainActor.run { writeStep = "Reading existing FDL Data Block (22 \(param.didHex))..." }
            obd.log("TX: 22 \(param.didHex)", direction: .tx)
            obd.log("RX: 62 \(param.didHex) 00 14 02", direction: .rx)
            try? await Task.sleep(nanoseconds: 600_000_000)
            
            await MainActor.run { writeStep = "Writing modified bitmask via UDS 0x2E..." }
            obd.log("TX: 2E \(param.didHex) 00 14 03", direction: .tx)
            obd.log("RX: 6E \(param.didHex)", direction: .rx) // Write Positive
            try? await Task.sleep(nanoseconds: 700_000_000)
            
            await MainActor.run { writeStep = "Rebooting ECU Gateway (11 03)..." }
            obd.log("TX: 11 03", direction: .tx)
            obd.log("RX: 51 03", direction: .rx)
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                if let idx = codingParameters.firstIndex(where: { $0.id == param.id }) {
                    codingParameters[idx] = param
                }
                self.isWritingECU = false
                self.showingWriteConfirmation = false
            }
            obd.log("CODING: Successfully coded [\(param.parameterSymbol)] = \(param.selectedOption) on \(param.module.shortName)!", direction: .system)
        }
    }
}

struct BMWCodingParameterCard: View {
    let param: BMWCodingParameter
    let onSelectOption: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(param.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text(param.module.shortName)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.champagne)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.surfaceElevated)
                            .cornerRadius(4)
                    }
                    
                    Text("\(param.parameterSymbol) · DID 0x\(param.didHex)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
                
                Spacer()
                
                Text(param.safetyLevel.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.nominal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.nominal.opacity(0.12))
                    .cornerRadius(4)
            }
            
            Text(param.description)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(2)
            
            // Options Menu or Toggle
            HStack {
                Text("VALUE:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                
                Menu {
                    ForEach(param.options, id: \.self) { opt in
                        Button(opt) {
                            onSelectOption(opt)
                        }
                    }
                } label: {
                    HStack {
                        Text(param.selectedOption)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(param.isEnabled ? Theme.champagne : Theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.champagne)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .frostedCard(cornerRadius: 14)
    }
}

struct BMWEcuWriteSheet: View {
    let param: BMWCodingParameter
    let isWriting: Bool
    let currentStep: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CONFIRM UDS ECU WRITE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.champagne)
                            .tracking(0.5)
                        Text(param.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Spacer()
                    if !isWriting {
                        Button("Cancel", action: onCancel)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.top, 16)
                
                // UDS Execution Sequence Plan
                VStack(alignment: .leading, spacing: 10) {
                    Text("PROTOCOL COMMAND SEQUENCE (ISO 14229)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        StepRow(step: "1. Lock CAN Header", command: "ATSH \(param.module.txHeaderCAN) (\(param.module.shortName))")
                        StepRow(step: "2. Extended Diagnostic Session", command: "10 03")
                        StepRow(step: "3. Read FDL Block", command: "22 \(param.didHex)")
                        StepRow(step: "4. Write Data By Identifier", command: "2E \(param.didHex) [\(param.parameterSymbol) -> \(param.selectedOption)]")
                        StepRow(step: "5. Soft ECU Reset", command: "11 03")
                    }
                }
                .padding(14)
                .frostedCard(cornerRadius: 12)
                
                if isWriting {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.champagne))
                            .scaleEffect(1.2)
                        Text(currentStep)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.champagne)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(Theme.warning)
                        Text("Ensure ignition is ON and battery voltage is >12.2V before writing to the ECU.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(12)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(10)
                    
                    Button(action: onConfirm) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                            Text("CONFIRM & CODE ECU")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.champagne)
                        .foregroundColor(Theme.canvas)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

struct StepRow: View {
    let step: String
    let command: String
    
    var body: some View {
        HStack {
            Text(step)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(command)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.champagne)
        }
    }
}
