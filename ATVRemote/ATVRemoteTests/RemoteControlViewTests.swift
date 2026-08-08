import XCTest
import SwiftUI
import ViewInspector
import ATVRemoteCore
@testable import ATV_Remote

@MainActor
final class RemoteControlViewTests: XCTestCase {

    private func createMockAppState() -> AppState {
        let factory = ServiceFactory()
        return AppState(factory: factory)
    }

    private func createTestDevice() -> AppleTVDevice {
        AppleTVDevice(
            id: "test-device",
            name: "Living Room TV",
            host: .name("192.168.1.100", nil),
            port: 49152
        )
    }

    func testDeviceNameIsDisplayed() throws {
        let appState = createMockAppState()
        let device = createTestDevice()

        let view = RemoteControlView(device: device)
            .environmentObject(appState)

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "Living Room TV"))
    }

    func testBackButtonExists() throws {
        let appState = createMockAppState()
        let device = createTestDevice()

        let view = RemoteControlView(device: device)
            .environmentObject(appState)

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "Back"))
    }
}

@MainActor
final class TouchpadViewTests: XCTestCase {

    func testTouchpadRenders() throws {
        let view = TouchpadView(
            onCommand: { _ in },
            longPressDuration: 0.6
        )

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(ViewType.GeometryReader.self))
    }
}

@MainActor
final class VolumeButtonTests: XCTestCase {

    func testVolumeUpButtonDisplaysPlusSymbol() throws {
        let view = VolumeButton(
            isUp: true,
            repeatInterval: 0.1,
            onCommand: { _ in }
        )

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "+"))
    }

    func testVolumeDownButtonDisplaysMinusSymbol() throws {
        let view = VolumeButton(
            isUp: false,
            repeatInterval: 0.1,
            onCommand: { _ in }
        )

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "−"))
    }
}
