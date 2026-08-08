import Foundation
import Combine

@MainActor
public final class MockConnectionService: ObservableObject, ConnectionServiceProtocol {
    @Published public private(set) var state: ConnectionState = .disconnected
    @Published public private(set) var connectedDevice: AppleTVDevice?
    @Published public private(set) var playbackInfo: PlaybackInfo?
    @Published public private(set) var isPlayingContent: Bool = false

    public var connectionDelay: TimeInterval = 0.3
    public var shouldFailConnection: Bool = false
    public var connectionError: ConnectionError = .connectionFailed
    public var shouldRequirePairing: Bool = false

    public private(set) var commandHistory: [RemoteCommand] = []
    public var onCommandSent: ((RemoteCommand) -> Void)?

    private let credentialsManager: any CredentialsManagerProtocol

    public init(credentialsManager: any CredentialsManagerProtocol) {
        self.credentialsManager = credentialsManager
    }

    public func connect(to device: AppleTVDevice) async throws {
        if shouldRequirePairing && !credentialsManager.hasPairing(for: device.id) {
            throw ConnectionError.notPaired
        }

        state = .connecting
        connectedDevice = device

        try? await Task.sleep(nanoseconds: UInt64(connectionDelay * 1_000_000_000))

        if shouldFailConnection {
            state = .failed(connectionError.localizedDescription ?? "Connection failed")
            connectedDevice = nil
            throw connectionError
        }

        state = .verifying
        try? await Task.sleep(nanoseconds: 100_000_000)
        state = .connected
    }

    public func disconnect() {
        state = .disconnected
        connectedDevice = nil
        playbackInfo = nil
        isPlayingContent = false
    }

    public func sendCommand(_ command: RemoteCommand) async throws {
        guard state == .connected else {
            throw ConnectionError.notConnected
        }

        commandHistory.append(command)
        onCommandSent?(command)

        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    public func sendKeyPress(key: HIDKey) async throws {
        try await sendCommand(.select)
    }

    public func sendLongPress(key: HIDKey, duration: TimeInterval) async throws {
        guard state == .connected else {
            throw ConnectionError.notConnected
        }
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    public var changePublisher: AnyPublisher<Void, Never> {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }

    public func setPlaybackInfo(_ info: PlaybackInfo?) {
        playbackInfo = info
        isPlayingContent = info?.isPlaying ?? false
    }

    public func simulateDisconnect() {
        state = .disconnected
        connectedDevice = nil
    }

    public func clearCommandHistory() {
        commandHistory.removeAll()
    }
}
