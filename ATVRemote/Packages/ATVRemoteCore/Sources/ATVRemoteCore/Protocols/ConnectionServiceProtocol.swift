import Foundation
import Combine

@MainActor
public protocol ConnectionServiceProtocol: ObservableObject {
    var state: ConnectionState { get }
    var connectedDevice: AppleTVDevice? { get }
    var playbackInfo: PlaybackInfo? { get }
    var isPlayingContent: Bool { get }

    /// Lets `AppState` forward connection changes, so views observing it
    /// re-render on now-playing updates.
    var changePublisher: AnyPublisher<Void, Never> { get }

    func connect(to device: AppleTVDevice) async throws
    func disconnect()
    func sendCommand(_ command: RemoteCommand) async throws
    func sendKeyPress(key: HIDKey) async throws
    func sendLongPress(key: HIDKey, duration: TimeInterval) async throws
}
