import Foundation

public struct PlaybackInfo: Sendable, Equatable {
    public enum PlaybackState: String, Sendable {
        case playing
        case paused
        case stopped
        case unknown
    }

    public let title: String?
    public let artist: String?
    public let album: String?
    public let duration: TimeInterval?
    public let position: TimeInterval?
    public let state: PlaybackState
    public let artworkData: Data?

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        duration: TimeInterval? = nil,
        position: TimeInterval? = nil,
        state: PlaybackState = .unknown,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.state = state
        self.artworkData = artworkData
    }

    public var progress: Double {
        guard let duration = duration, let position = position, duration > 0 else {
            return 0
        }
        return position / duration
    }

    public var isPlaying: Bool {
        state == .playing
    }

    public var hasContent: Bool {
        title != nil || artist != nil || album != nil
    }
}
