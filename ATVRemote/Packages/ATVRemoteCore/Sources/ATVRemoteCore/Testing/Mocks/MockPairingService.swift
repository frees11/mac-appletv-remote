import Foundation

@MainActor
public final class MockPairingService: ObservableObject, PairingServiceProtocol {
    @Published public private(set) var state: PairingState = .idle

    public var expectedPin: String = "1234"
    public var pairingDelay: TimeInterval = 0.5
    public var shouldFailPairing: Bool = false
    public var pairingError: PairingError = .connectionFailed

    public init() {}

    public func startPairing(device: AppleTVDevice) async throws -> @Sendable (String) async throws -> PairingCredentials {
        state = .processing

        try? await Task.sleep(nanoseconds: UInt64(pairingDelay * 1_000_000_000))

        if shouldFailPairing {
            state = .failed(pairingError.localizedDescription ?? "Pairing failed")
            throw pairingError
        }

        state = .waitingForPin

        return { [weak self] pin in
            guard let self = self else { throw PairingError.connectionFailed }
            return try await self.completePairing(pin: pin, device: device)
        }
    }

    @MainActor
    private func completePairing(pin: String, device: AppleTVDevice) async throws -> PairingCredentials {
        state = .processing

        try? await Task.sleep(nanoseconds: UInt64(pairingDelay * 1_000_000_000))

        guard pin == expectedPin else {
            state = .failed("Invalid PIN")
            throw PairingError.errorCode(2)
        }

        let credentials = PairingCredentials(
            deviceId: device.id,
            ltpk: Data(repeating: 0x01, count: 32),
            ltsk: Data(repeating: 0x02, count: 32),
            peerPublicKey: Data(repeating: 0x03, count: 32),
            identifier: Data("mock-identifier".utf8),
            pairingId: UUID().uuidString
        )

        state = .completed(credentials)
        return credentials
    }

    public func cancel() {
        state = .idle
    }
}
