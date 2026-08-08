import Foundation
import Network
import Combine

@MainActor
public final class MockDeviceDiscoveryService: ObservableObject, DeviceDiscoveryServiceProtocol {
    @Published public private(set) var devices: [AppleTVDevice] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var error: Error?
    @Published public private(set) var debugStatus: String = "Mock: Not started"

    public var mockDevices: [AppleTVDevice] = []
    public var scanDelay: TimeInterval = 0.5
    public var shouldFailScanning: Bool = false
    public var scanningError: Error?

    public var changePublisher: AnyPublisher<Void, Never> {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }

    public init() {}

    public func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        debugStatus = "Mock: Scanning... (\(mockDevices.count) mock devices configured)"
        print("🔧 MockDeviceDiscoveryService: startScanning called, mockDevices.count = \(mockDevices.count)")

        Task {
            try? await Task.sleep(nanoseconds: UInt64(scanDelay * 1_000_000_000))

            if shouldFailScanning {
                error = scanningError ?? DeviceDiscoveryError.resolutionFailed
                isScanning = false
                debugStatus = "Mock: Error"
            } else {
                devices = mockDevices
                isScanning = false
                debugStatus = "Mock: Found \(mockDevices.count) device(s)"
                print("🔧 MockDeviceDiscoveryService: scan complete, devices.count = \(devices.count)")
            }
        }
    }

    public func stopScanning() {
        isScanning = false
        debugStatus = "Mock: Stopped"
    }

    public func resolveDevice(_ device: AppleTVDevice) async throws -> (host: String, port: UInt16) {
        return ("192.168.1.100", 49152)
    }

    public func addDevice(_ device: AppleTVDevice) {
        mockDevices.append(device)
        if isScanning { devices = mockDevices }
    }

    public func removeDevice(id: String) {
        mockDevices.removeAll { $0.id == id }
        devices = mockDevices
    }

    public func simulateDeviceAppearing(_ device: AppleTVDevice, delay: TimeInterval = 1.0) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            mockDevices.append(device)
            devices = mockDevices
            debugStatus = "Mock: Found \(devices.count) device(s)"
        }
    }
}
