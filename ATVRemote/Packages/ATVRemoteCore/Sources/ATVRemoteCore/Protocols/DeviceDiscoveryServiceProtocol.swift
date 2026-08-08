import Foundation
import Network
import Combine

@MainActor
public protocol DeviceDiscoveryServiceProtocol: ObservableObject {
    var devices: [AppleTVDevice] { get }
    var isScanning: Bool { get }
    var error: Error? { get }
    var debugStatus: String { get }
    var changePublisher: AnyPublisher<Void, Never> { get }

    func startScanning()
    func stopScanning()
    func resolveDevice(_ device: AppleTVDevice) async throws -> (host: String, port: UInt16)
}
