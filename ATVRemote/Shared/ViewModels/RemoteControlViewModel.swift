import SwiftUI
import ATVRemoteCore

@MainActor
@Observable
final class RemoteControlViewModel {
    var playbackInfo: PlaybackInfo?
    var isConnected: Bool = false
    var error: String?

    private let device: AppleTVDevice

    init(device: AppleTVDevice) {
        self.device = device
    }

    func connect() async {
        isConnected = true
    }

    func disconnect() {
        isConnected = false
    }

    func sendCommand(_ command: RemoteCommand) async {
        print("Sending command: \(command.rawValue) to \(device.name)")
    }

    func refreshPlaybackInfo() async {
    }
}
