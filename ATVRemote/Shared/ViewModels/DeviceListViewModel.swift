import SwiftUI
import ATVRemoteCore

@MainActor
@Observable
final class DeviceListViewModel {
    var devices: [AppleTVDevice] = []
    var isScanning: Bool = false
    var error: String?
    var showPinDialog: Bool = false
    var pinInput: String = ""
    var selectedDeviceForPairing: AppleTVDevice?

    private let discoveryService: DeviceDiscoveryService
    private let credentialsManager: CredentialsManager

    init(
        discoveryService: DeviceDiscoveryService,
        credentialsManager: CredentialsManager
    ) {
        self.discoveryService = discoveryService
        self.credentialsManager = credentialsManager
    }

    func startScanning() {
        discoveryService.startScanning()
    }

    func stopScanning() {
        discoveryService.stopScanning()
    }

    func refreshDevices() {
        devices = discoveryService.devices.map { device in
            var updated = device
            updated.isPaired = credentialsManager.hasPairing(for: device.id)
            return updated
        }
        isScanning = discoveryService.isScanning
        if let serviceError = discoveryService.error {
            error = serviceError.localizedDescription
        }
    }

    func startPairing(_ device: AppleTVDevice) {
        selectedDeviceForPairing = device
        pinInput = ""
        showPinDialog = true
    }

    func submitPin() async {
        guard let device = selectedDeviceForPairing else { return }
        guard pinInput.count == 4 else {
            error = "PIN must be 4 digits"
            return
        }

        showPinDialog = false
        selectedDeviceForPairing = nil
        pinInput = ""
    }

    func unpair(_ device: AppleTVDevice) {
        do {
            try credentialsManager.delete(for: device.id)
            refreshDevices()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
