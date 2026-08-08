import XCTest
import Network
@testable import ATVRemoteCore

final class ATVRemoteCoreTests: XCTestCase {
    func testVersion() throws {
        XCTAssertEqual(ATVRemoteCore.version, "1.0.0")
    }

    func testRemoteCommand() throws {
        let up = RemoteCommand.up
        XCTAssertFalse(up.isLongPress)

        let longUp = RemoteCommand.longUp
        XCTAssertTrue(longUp.isLongPress)
        XCTAssertEqual(longUp.shortPressVariant, .up)
    }

    func testPlaybackInfo() throws {
        let info = PlaybackInfo(
            title: "Test Song",
            artist: "Test Artist",
            duration: 180,
            position: 90,
            state: .playing
        )

        XCTAssertEqual(info.progress, 0.5)
        XCTAssertTrue(info.isPlaying)
        XCTAssertTrue(info.hasContent)
    }

    func testIPAddressFromResolvedHost() throws {
        let resolved = makeDevice(host: .ipv4(IPv4Address("192.168.88.25")!))
        XCTAssertEqual(resolved.ipAddress, "192.168.88.25")

        let unresolved = makeDevice(host: .name("living-room-tv.local", nil))
        XCTAssertNil(unresolved.ipAddress)
    }

    func testModelDisplayName() throws {
        XCTAssertEqual(makeDevice(model: "AppleTV6,2").modelDisplayName, "Apple TV 4K")
        XCTAssertEqual(makeDevice(model: "AppleTV11,1").modelDisplayName, "Apple TV 4K (2nd gen)")
        XCTAssertEqual(makeDevice(model: "AppleTV5,3").modelDisplayName, "Apple TV HD")
        XCTAssertEqual(makeDevice(model: "AppleTV17,1").modelDisplayName, "AppleTV17,1")
        XCTAssertNil(makeDevice(model: nil).modelDisplayName)
    }

    func testNowPlayingParserReadsPlaybackQueueMetadata() throws {
        var metadata = ContentItemMetadata()
        metadata.title = "The Morning Show"
        metadata.trackArtistName = "Season 4, Episode 3"
        metadata.albumName = "Apple TV+"
        metadata.duration = 123
        metadata.elapsedTime = 3
        metadata.playbackRate = 1

        var item = ContentItem()
        item.metadata = metadata

        var queue = PlaybackQueue()
        queue.contentItems = [item]

        var message = SetStateMessage()
        message.playbackQueue = queue
        message.playbackState = .playing

        let info = try XCTUnwrap(NowPlayingParser.playbackInfo(from: message))
        XCTAssertEqual(info.title, "The Morning Show")
        XCTAssertEqual(info.artist, "Season 4, Episode 3")
        XCTAssertEqual(info.album, "Apple TV+")
        XCTAssertEqual(info.duration, 123)
        XCTAssertEqual(info.position, 3)
        XCTAssertEqual(info.state, .playing)
    }

    func testNowPlayingParserFallsBackToNowPlayingInfo() throws {
        var legacy = NowPlayingInfo()
        legacy.title = "Time"
        legacy.artist = "Hans Zimmer"
        legacy.album = "Inception"
        legacy.playbackRate = 0

        var message = SetStateMessage()
        message.nowPlayingInfo = legacy

        let info = try XCTUnwrap(NowPlayingParser.playbackInfo(from: message))
        XCTAssertEqual(info.title, "Time")
        XCTAssertEqual(info.artist, "Hans Zimmer")
        XCTAssertEqual(info.album, "Inception")
        XCTAssertEqual(info.state, .paused, "zero playback rate without explicit state means paused")
    }

    func testNowPlayingParserReturnsNilWithoutContent() throws {
        XCTAssertNil(NowPlayingParser.playbackInfo(from: SetStateMessage()))
    }

    func testNowPlayingParserMapsPausedState() throws {
        var metadata = ContentItemMetadata()
        metadata.title = "Test Song"
        metadata.playbackRate = 1

        var item = ContentItem()
        item.metadata = metadata

        var queue = PlaybackQueue()
        queue.contentItems = [item]

        var message = SetStateMessage()
        message.playbackQueue = queue
        message.playbackState = .paused

        let info = try XCTUnwrap(NowPlayingParser.playbackInfo(from: message))
        XCTAssertEqual(info.state, .paused, "explicit playback state wins over playback rate")
    }

    private func makeDevice(
        host: NWEndpoint.Host = .ipv4(IPv4Address("192.168.1.1")!),
        model: String? = nil
    ) -> AppleTVDevice {
        AppleTVDevice(
            id: "test",
            name: "Test",
            host: host,
            port: .init(integerLiteral: 49152),
            model: model
        )
    }
}
