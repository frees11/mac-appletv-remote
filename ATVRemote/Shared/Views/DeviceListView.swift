import SwiftUI
import ATVRemoteCore

struct DeviceListView: View {
    @EnvironmentObject var appState: AppState
    @State private var viewModel: DeviceListViewModel?
    @State private var showPinDialog = false
    @State private var pinInput = ""
    @State private var selectedDevice: AppleTVDevice?
    @State private var isStartingPairing = false
    @State private var isSubmittingPin = false
    @State private var scanCount = 0
    @State private var pinSecondsRemaining = 0

    private var isPinExpired: Bool {
        pinSecondsRemaining <= 0
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if appState.discoveryService.isScanning && appState.discoveryService.devices.isEmpty {
                scanningView
            } else if appState.discoveryService.devices.isEmpty {
                emptyStateView
            } else {
                deviceListView
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear {
            appState.discoveryService.startScanning()
        }
        .sheet(isPresented: $showPinDialog) {
            pinDialogView
        }
    }

    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "appletv.fill")
                .font(.system(size: 48))
                .foregroundColor(.white)
                .accessibilityIdentifier(AccessibilityID.DeviceList.headerIcon)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("App Icon")

            Text("ATV Remote Pro")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .accessibilityIdentifier(AccessibilityID.DeviceList.headerTitle)
                .accessibilityLabel("ATV Remote Pro")
                .accessibilityAddTraits(.isHeader)

            Text("Select your Apple TV")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 32)
        .accessibilityElement(children: .contain)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
                .accessibilityIdentifier(AccessibilityID.DeviceList.scanningProgress)

            Text("Scanning for Apple TV devices...")
                .foregroundColor(AppColors.textSecondary)

            Text("Debug: \(appState.discoveryService.debugStatus)")
                .font(.caption)
                .foregroundColor(.yellow)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary)
                .accessibilityIdentifier(AccessibilityID.DeviceList.emptyStateIcon)

            Text("No Apple TV found")
                .font(.headline)
                .foregroundColor(.white)
                .accessibilityIdentifier(AccessibilityID.DeviceList.emptyStateTitle)

            Text("Make sure your Apple TV is on the same network")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Text("Debug: \(appState.discoveryService.debugStatus) (clicks: \(scanCount))")
                .font(.caption)
                .foregroundColor(.yellow)

            if let error = appState.discoveryService.error {
                Text("Error: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .accessibilityIdentifier(AccessibilityID.DeviceList.errorBanner)
            }

            Button {
                scanCount += 1
                appState.discoveryService.startScanning()
            } label: {
                Label("Scan Again", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            .accessibilityIdentifier(AccessibilityID.DeviceList.scanButton)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deviceListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let error = appState.pairingError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityIdentifier(AccessibilityID.DeviceList.errorBanner)
                }
                ForEach(appState.discoveryService.devices) { device in
                    let isPaired = appState.isPaired(device)
                    let _ = NSLog("🔍 Device \(device.id): isPaired=\(isPaired)")
                    DeviceRow(
                        device: device,
                        isPaired: isPaired,
                        isPairing: isStartingPairing && selectedDevice?.id == device.id,
                        onConnect: {
                            connectToDevice(device)
                        },
                        onPair: {
                            startPairing(device)
                        },
                        onUnpair: {
                            unpairDevice(device)
                        }
                    )
                    .accessibilityIdentifier(AccessibilityID.DeviceList.deviceRow(device.id))
                }
            }
            .padding()
        }
        .accessibilityIdentifier(AccessibilityID.DeviceList.scrollView)
    }

    private var pinDialogView: some View {
        VStack(spacing: 24) {
            Text(isPinExpired ? "Expired" : "Enter PIN")
                .font(.headline)

            if isPinExpired {
                Text("Session expired")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 8) {
                    Text("Enter the 4-digit PIN shown on your Apple TV")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Label("\(pinSecondsRemaining)s", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            TextField("PIN", text: $pinInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .multilineTextAlignment(.center)
                .font(.title2.monospaced())
                .disabled(isSubmittingPin || isPinExpired)
                .accessibilityIdentifier(AccessibilityID.PinDialog.textField)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif

            if let error = appState.pairingError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button(isPinExpired ? "Close" : "Cancel") {
                    appState.cancelPairing()
                    showPinDialog = false
                    pinInput = ""
                    selectedDevice = nil
                }
                .buttonStyle(.bordered)
                .disabled(isSubmittingPin)
                .accessibilityIdentifier(AccessibilityID.PinDialog.cancelButton)

                if isPinExpired {
                    Button("Resend") {
                        resendPairing()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isStartingPairing)
                } else {
                    Button {
                        submitPin()
                    } label: {
                        if isSubmittingPin {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 60)
                        } else {
                            Text("Connect")
                                .frame(width: 60)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pinInput.count != 4 || isSubmittingPin)
                    .accessibilityIdentifier(AccessibilityID.PinDialog.connectButton)
                }
            }
        }
        .padding(32)
        .frame(width: 300)
        .accessibilityIdentifier(AccessibilityID.PinDialog.container)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if pinSecondsRemaining > 0 {
                    pinSecondsRemaining -= 1
                }
            }
        }
    }

    private func connectToDevice(_ device: AppleTVDevice) {
        Task {
            do {
                try await appState.connectToDevice(device)
            } catch {
                appState.pairingError = "Connection failed: \(error.localizedDescription)"
            }
        }
    }

    private func startPairing(_ device: AppleTVDevice) {
        selectedDevice = device
        pinInput = ""
        isStartingPairing = true

        Task {
            do {
                try await appState.startPairing(device: device)
                isStartingPairing = false
                pinSecondsRemaining = PairingService.pinValiditySeconds
                showPinDialog = true
            } catch {
                isStartingPairing = false
                appState.pairingError = "Pairing failed: \(error.localizedDescription)"
            }
        }
    }

    private func resendPairing() {
        guard let device = selectedDevice else { return }

        appState.cancelPairing()
        pinInput = ""
        isStartingPairing = true

        Task {
            do {
                try await appState.startPairing(device: device)
                isStartingPairing = false
                pinSecondsRemaining = PairingService.pinValiditySeconds
            } catch {
                isStartingPairing = false
                appState.pairingError = "Pairing failed: \(error.localizedDescription)"
            }
        }
    }

    private func submitPin() {
        guard selectedDevice != nil else { return }
        isSubmittingPin = true

        Task {
            do {
                try await appState.completePairing(pin: pinInput)
                isSubmittingPin = false
                showPinDialog = false
                selectedDevice = nil
                pinInput = ""
            } catch {
                isSubmittingPin = false
            }
        }
    }

    private func unpairDevice(_ device: AppleTVDevice) {
        appState.unpair(device)
    }
}

struct DeviceRow: View {
    let device: AppleTVDevice
    let isPaired: Bool
    let isPairing: Bool
    let onConnect: () -> Void
    let onPair: () -> Void
    let onUnpair: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "appletv.fill")
                .font(.system(size: 26))
                .foregroundColor(.white)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .accessibilityIdentifier(AccessibilityID.DeviceList.deviceName(device.id))

                if let ipAddress = device.ipAddress {
                    Text(ipAddress)
                        .font(.caption.monospaced())
                        .foregroundColor(AppColors.textSecondary)
                }

                HStack(spacing: 8) {
                    if let model = device.modelDisplayName {
                        Text(model)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }

                    if isPaired {
                        Label("Paired", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }

            Spacer()

            if isPaired {
                HStack(spacing: 8) {
                    Button("Connect") {
                        onConnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier(AccessibilityID.DeviceList.connectButton(device.id))

                    Menu {
                        Button(role: .destructive) {
                            onUnpair()
                        } label: {
                            Label("Unpair", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .accessibilityIdentifier(AccessibilityID.DeviceList.unpairButton(device.id))
                }
            } else {
                Button {
                    onPair()
                } label: {
                    if isPairing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 40)
                    } else {
                        Text("Pair")
                            .frame(width: 40)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
                .controlSize(.small)
                .disabled(isPairing)
                .accessibilityIdentifier(AccessibilityID.DeviceList.pairButton(device.id))
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    DeviceListView()
        .environmentObject(AppState())
        .frame(width: 400, height: 800)
}
