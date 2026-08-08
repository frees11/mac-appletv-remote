import Foundation

@MainActor
public protocol PairingServiceProtocol: ObservableObject {
    var state: PairingState { get }

    func startPairing(device: AppleTVDevice) async throws -> @Sendable (String) async throws -> PairingCredentials
    func cancel()
}
