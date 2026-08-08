import Foundation

public enum NowPlayingParser {

    public static func playbackInfo(from message: SetStateMessage) -> PlaybackInfo? {
        let metadata = message.playbackQueue.contentItems.first?.metadata
        let legacy: NowPlayingInfo? = message.hasNowPlayingInfo ? message.nowPlayingInfo : nil

        let title = metadata.flatMap(title(of:)) ?? legacy.flatMap(title(of:))
        let artist = metadata.flatMap(artist(of:)) ?? legacy.flatMap(artist(of:))
        let album = metadata.flatMap(album(of:)) ?? legacy.flatMap(album(of:))
        let duration = metadata.flatMap(duration(of:)) ?? legacy.flatMap(duration(of:))
        let position = metadata.flatMap(elapsedTime(of:)) ?? legacy.flatMap(elapsedTime(of:))
        let rate = metadata.flatMap(playbackRate(of:)) ?? legacy.flatMap(playbackRate(of:))

        let state = state(of: message, playbackRate: rate)

        guard title != nil || artist != nil || album != nil else {
            return nil
        }

        return PlaybackInfo(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            position: position,
            state: state
        )
    }

    private static func state(of message: SetStateMessage, playbackRate: Float?) -> PlaybackInfo.PlaybackState {
        if message.hasPlaybackState {
            switch message.playbackState {
            case .playing, .seeking:
                return .playing
            case .paused, .interrupted:
                return .paused
            case .stopped:
                return .stopped
            case .unknown:
                break
            }
        }

        guard let playbackRate else {
            return .unknown
        }
        return playbackRate > 0 ? .playing : .paused
    }

    private static func title(of metadata: ContentItemMetadata) -> String? {
        metadata.hasTitle ? nonEmpty(metadata.title) : nil
    }

    private static func artist(of metadata: ContentItemMetadata) -> String? {
        if metadata.hasTrackArtistName, let value = nonEmpty(metadata.trackArtistName) {
            return value
        }
        if metadata.hasAlbumArtistName, let value = nonEmpty(metadata.albumArtistName) {
            return value
        }
        return metadata.hasSubtitle ? nonEmpty(metadata.subtitle) : nil
    }

    private static func album(of metadata: ContentItemMetadata) -> String? {
        metadata.hasAlbumName ? nonEmpty(metadata.albumName) : nil
    }

    private static func duration(of metadata: ContentItemMetadata) -> TimeInterval? {
        metadata.hasDuration ? metadata.duration : nil
    }

    private static func elapsedTime(of metadata: ContentItemMetadata) -> TimeInterval? {
        metadata.hasElapsedTime ? metadata.elapsedTime : nil
    }

    private static func playbackRate(of metadata: ContentItemMetadata) -> Float? {
        metadata.hasPlaybackRate ? metadata.playbackRate : nil
    }

    private static func title(of info: NowPlayingInfo) -> String? {
        info.hasTitle ? nonEmpty(info.title) : nil
    }

    private static func artist(of info: NowPlayingInfo) -> String? {
        info.hasArtist ? nonEmpty(info.artist) : nil
    }

    private static func album(of info: NowPlayingInfo) -> String? {
        info.hasAlbum ? nonEmpty(info.album) : nil
    }

    private static func duration(of info: NowPlayingInfo) -> TimeInterval? {
        info.hasDuration ? info.duration : nil
    }

    private static func elapsedTime(of info: NowPlayingInfo) -> TimeInterval? {
        info.hasElapsedTime ? info.elapsedTime : nil
    }

    private static func playbackRate(of info: NowPlayingInfo) -> Float? {
        info.hasPlaybackRate ? info.playbackRate : nil
    }

    private static func nonEmpty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}
