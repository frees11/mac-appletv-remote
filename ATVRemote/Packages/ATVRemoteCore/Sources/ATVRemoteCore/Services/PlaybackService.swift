import Foundation
import Combine
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum PlaybackState: Equatable, Sendable {
    case idle
    case playing
    case paused
    case stopped
}

@MainActor
public final class PlaybackService: ObservableObject {
    @Published public private(set) var playbackState: PlaybackState = .idle
    @Published public private(set) var currentTrack: TrackInfo?
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var artworkImage: PlatformImage?

    private var cancellables = Set<AnyCancellable>()
    private weak var connectionService: ConnectionService?
    private var progressTimer: Timer?

    public init() {}

    public func bind(to connectionService: ConnectionService) {
        self.connectionService = connectionService

        connectionService.$playbackInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.updatePlaybackInfo(info)
            }
            .store(in: &cancellables)

        connectionService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if state == .disconnected {
                    self?.reset()
                }
            }
            .store(in: &cancellables)
    }

    public func play() async throws {
        try await connectionService?.sendCommand(.playPause)
    }

    public func pause() async throws {
        try await connectionService?.sendCommand(.playPause)
    }

    public func next() async throws {
        try await connectionService?.sendCommand(.skipForward)
    }

    public func previous() async throws {
        try await connectionService?.sendCommand(.skipBackward)
    }

    public func volumeUp() async throws {
        try await connectionService?.sendCommand(.volumeUp)
    }

    public func volumeDown() async throws {
        try await connectionService?.sendCommand(.volumeDown)
    }

    private func updatePlaybackInfo(_ info: PlaybackInfo?) {
        guard let info = info else {
            reset()
            return
        }

        currentTrack = TrackInfo(
            title: info.title ?? "Unknown",
            artist: info.artist,
            album: info.album
        )

        duration = info.duration ?? 0
        progress = info.position ?? 0

        if info.isPlaying {
            playbackState = .playing
            startProgressTimer()
        } else {
            playbackState = .paused
            stopProgressTimer()
        }

        if let artworkData = info.artworkData {
            loadArtwork(from: artworkData)
        } else {
            artworkImage = nil
        }
    }

    private func loadArtwork(from data: Data) {
        #if canImport(AppKit)
        artworkImage = NSImage(data: data)
        #elseif canImport(UIKit)
        artworkImage = UIImage(data: data)
        #endif
    }

    private func startProgressTimer() {
        stopProgressTimer()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.playbackState == .playing && self.progress < self.duration {
                    self.progress += 1.0
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func reset() {
        playbackState = .idle
        currentTrack = nil
        progress = 0
        duration = 0
        artworkImage = nil
        stopProgressTimer()
    }
}

public struct TrackInfo: Equatable, Sendable {
    public let title: String
    public let artist: String?
    public let album: String?

    public var displayTitle: String {
        if let artist = artist, !artist.isEmpty {
            return "\(title) - \(artist)"
        }
        return title
    }
}

#if canImport(AppKit)
public typealias PlatformImage = NSImage
#elseif canImport(UIKit)
public typealias PlatformImage = UIImage
#endif
