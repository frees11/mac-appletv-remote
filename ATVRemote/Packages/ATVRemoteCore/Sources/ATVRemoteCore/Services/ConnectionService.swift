import Foundation
import Combine

public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case verifying
    case connected
    case failed(String)
}

@MainActor
public final class ConnectionService: ObservableObject, ConnectionServiceProtocol {
    @Published public private(set) var state: ConnectionState = .disconnected
    @Published public private(set) var connectedDevice: AppleTVDevice?
    @Published public private(set) var playbackInfo: PlaybackInfo?
    @Published public private(set) var isPlayingContent: Bool = false

    public var changePublisher: AnyPublisher<Void, Never> {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }

    private var companionConnection: CompanionConnection?
    private var mrpConnection: MRPConnection?
    private var credentials: PairingCredentials?
    private let credentialsManager: CredentialsManager

    public init(credentialsManager: CredentialsManager = CredentialsManager()) {
        self.credentialsManager = credentialsManager
    }

    public func connect(to device: AppleTVDevice) async throws {
        NSLog("[Connection] Starting connection to device: %@", device.name)

        guard let storedCredentials = try? credentialsManager.load(for: device.id) else {
            NSLog("[Connection] ERROR: No stored credentials for device")
            throw ConnectionError.notPaired
        }

        NSLog("[Connection] Loaded credentials, pairingId: %@", storedCredentials.pairingId)

        state = .connecting
        connectedDevice = device
        credentials = storedCredentials

        let connection = CompanionConnection()
        self.companionConnection = connection

        do {
            NSLog("[Connection] Connecting to companion port...")
            try await connection.connect(host: device.host, port: device.port)

            state = .verifying
            NSLog("[Connection] Starting pair-verify...")
            try await connection.pairVerify(credentials: storedCredentials)

            NSLog("[Connection] Connection succeeded!")
            state = .connected

            startNowPlayingUpdates(for: device)
        } catch {
            NSLog("[Connection] ERROR: %@", error.localizedDescription)
            state = .failed(error.localizedDescription)
            companionConnection = nil
            connectedDevice = nil
            throw error
        }
    }

    /// Now-playing arrives over MediaRemote, which is a separate service from
    /// Companion. Devices without direct MRP simply never report it, so a
    /// failure here must not tear down the working Companion session.
    private func startNowPlayingUpdates(for device: AppleTVDevice) {
        guard let mrpHost = device.mrpHost, let mrpPort = device.mrpPort else {
            NSLog("[Connection] Device advertises no MediaRemote service, now-playing unavailable")
            return
        }

        let connection = MRPConnection(host: mrpHost, port: mrpPort, clientIdentifier: device.id)
        connection.delegate = self
        mrpConnection = connection

        Task {
            do {
                try await connection.connect()
            } catch {
                NSLog("[Connection] MediaRemote connection failed: %@", error.localizedDescription)
                mrpConnection = nil
            }
        }
    }

    public func disconnect() {
        mrpConnection?.disconnect()
        mrpConnection = nil
        companionConnection?.disconnect()
        companionConnection = nil
        connectedDevice = nil
        credentials = nil
        playbackInfo = nil
        isPlayingContent = false
        state = .disconnected
    }

    public func sendCommand(_ command: RemoteCommand) async throws {
        guard let connection = companionConnection, state == .connected else {
            throw ConnectionError.notConnected
        }

        if command.isLongPress {
            if let shortVariant = command.shortPressVariant {
                let hidCommand = mapRemoteCommandToHID(shortVariant)
                try await connection.sendHIDCommand(hidCommand, buttonState: 1)
                try await Task.sleep(nanoseconds: 2_000_000_000)
                try await connection.sendHIDCommand(hidCommand, buttonState: 2)
            }
        } else {
            let hidCommand = mapRemoteCommandToHID(command)
            try await connection.pressButton(hidCommand)
        }
    }

    public func sendKeyPress(key: HIDKey) async throws {
        try await sendCommand(.select)
    }

    public func sendLongPress(key: HIDKey, duration: TimeInterval = 2.0) async throws {
        guard let connection = companionConnection, state == .connected else {
            throw ConnectionError.notConnected
        }

        try await connection.sendHIDCommand(.select, buttonState: 1)
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        try await connection.sendHIDCommand(.select, buttonState: 2)
    }

    private func mapRemoteCommandToHID(_ command: RemoteCommand) -> HIDCommand {
        switch command {
        case .up, .longUp: return .up
        case .down, .longDown: return .down
        case .left, .longLeft: return .left
        case .right, .longRight: return .right
        case .select, .longSelect: return .select
        case .menu: return .menu
        case .home, .topMenu, .tv, .controlCenter: return .home
        case .playPause, .play, .pause, .stop, .next, .previous, .skipForward, .skipBackward: return .playPause
        case .volumeUp: return .volumeUp
        case .volumeDown: return .volumeDown
        case .mute, .power, .powerOff: return .select
        }
    }
}

extension ConnectionService: MRPConnectionDelegate {
    public func connectionDidConnect(_ connection: MRPConnection) {
        NSLog("[Connection] MediaRemote connected, now-playing updates enabled")
    }

    public func connectionDidDisconnect(_ connection: MRPConnection) {
        NSLog("[Connection] MediaRemote disconnected")
        mrpConnection = nil
        playbackInfo = nil
        isPlayingContent = false
    }

    public func connection(_ connection: MRPConnection, didReceiveMessage message: ProtobufMessage) {
        guard message.type == .setStateMessage, message.hasSetStateMessage else {
            return
        }

        let info = NowPlayingParser.playbackInfo(from: message.setStateMessage)
        playbackInfo = info
        isPlayingContent = info?.isPlaying ?? false
        NSLog("[Connection] Now playing: %@", info?.title ?? "nothing")
    }

    public func connection(_ connection: MRPConnection, didReceiveError error: Error) {
        NSLog("[Connection] MediaRemote error: %@", error.localizedDescription)
    }
}

public enum ConnectionError: Error, LocalizedError {
    case notConnected
    case notPaired
    case connectionFailed

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to any Apple TV"
        case .notPaired:
            return "Device is not paired. Please pair first."
        case .connectionFailed:
            return "Failed to connect to Apple TV"
        }
    }
}
