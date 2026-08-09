import XCTest
@testable import ATVRemoteCore

final class DiscoveryFilterTests: XCTestCase {
    func testRealAppleTVModelsAreAccepted() {
        XCTAssertTrue(AppleTVDevice.isAppleTV(model: "AppleTV6,2"))
        XCTAssertTrue(AppleTVDevice.isAppleTV(model: "AppleTV14,1"))
    }

    func testMissingModelIsRejected() {
        XCTAssertFalse(
            AppleTVDevice.isAppleTV(model: nil),
            "Macs and iPads publish _companion-link._tcp without an rpMd key, so a missing model must not pass"
        )
    }

    func testEmptyModelIsRejected() {
        XCTAssertFalse(AppleTVDevice.isAppleTV(model: ""))
    }

    func testOtherAppleHardwareIsRejected() {
        XCTAssertFalse(AppleTVDevice.isAppleTV(model: "MacBookPro18,3"))
        XCTAssertFalse(AppleTVDevice.isAppleTV(model: "iPad13,4"))
    }

    func testModelMatchIsCaseSensitive() {
        XCTAssertFalse(AppleTVDevice.isAppleTV(model: "appletv6,2"))
    }
}
