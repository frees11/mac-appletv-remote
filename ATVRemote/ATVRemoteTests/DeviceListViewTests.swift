import XCTest
import SwiftUI
import ViewInspector
import ATVRemoteCore
@testable import ATV_Remote

@MainActor
final class DeviceListViewTests: XCTestCase {

    private func createMockFactory(
        devices: [AppleTVDevice] = [],
        isScanning: Bool = false
    ) -> ServiceFactory {
        let factory = ServiceFactory()

        if let mockDiscovery = factory.createDiscoveryService() as? MockDeviceDiscoveryService {
            mockDiscovery.mockDevices = devices
            mockDiscovery.scanDelay = 0
            if isScanning {
                mockDiscovery.startScanning()
            }
        }

        return factory
    }

    private func createAppState(factory: ServiceFactory) -> AppState {
        return AppState(factory: factory)
    }

    func testEmptyStateIsShownWhenNoDevices() throws {
        let factory = createMockFactory(devices: [], isScanning: false)
        let appState = createAppState(factory: factory)

        let view = DeviceListView()
            .environmentObject(appState)

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "No Apple TV found"))
    }

    func testScanningIndicatorIsShownWhenScanning() throws {
        let factory = ServiceFactory()

        if let mockDiscovery = factory.createDiscoveryService() as? MockDeviceDiscoveryService {
            mockDiscovery.mockDevices = []
            mockDiscovery.scanDelay = 10
        }

        let appState = createAppState(factory: factory)
        appState.discoveryService.startScanning()

        let view = DeviceListView()
            .environmentObject(appState)

        let sut = try view.inspect()

        XCTAssertTrue(appState.discoveryService.isScanning)
        XCTAssertNoThrow(try sut.find(text: "Scanning for Apple TV devices..."))
    }

    func testHeaderTitleIsDisplayed() throws {
        let factory = createMockFactory()
        let appState = createAppState(factory: factory)

        let view = DeviceListView()
            .environmentObject(appState)

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "ATV Remote Pro"))
        XCTAssertNoThrow(try sut.find(text: "Select your Apple TV"))
    }

    func testScanButtonExistsInEmptyState() throws {
        let factory = createMockFactory(devices: [], isScanning: false)
        let appState = createAppState(factory: factory)

        let view = DeviceListView()
            .environmentObject(appState)

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "Scan Again"))
    }
}

@MainActor
final class DeviceRowTests: XCTestCase {

    func testUnpairedDeviceShowsPairButton() throws {
        let device = AppleTVDevice(
            id: "test-device",
            name: "Test TV",
            host: .name("192.168.1.100", nil),
            port: 49152
        )

        let view = DeviceRow(
            device: device,
            isPaired: false,
            isPairing: false,
            onConnect: {},
            onPair: {},
            onUnpair: {}
        )

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "Pair"))
    }

    func testPairedDeviceShowsConnectButton() throws {
        let device = AppleTVDevice(
            id: "test-device",
            name: "Test TV",
            host: .name("192.168.1.100", nil),
            port: 49152
        )

        let view = DeviceRow(
            device: device,
            isPaired: true,
            isPairing: false,
            onConnect: {},
            onPair: {},
            onUnpair: {}
        )

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "Connect"))
        XCTAssertNoThrow(try sut.find(text: "Paired"))
    }

    func testDeviceNameIsDisplayed() throws {
        let device = AppleTVDevice(
            id: "test-device",
            name: "Living Room TV",
            host: .name("192.168.1.100", nil),
            port: 49152,
            model: "Apple TV 4K"
        )

        let view = DeviceRow(
            device: device,
            isPaired: false,
            isPairing: false,
            onConnect: {},
            onPair: {},
            onUnpair: {}
        )

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(text: "Living Room TV"))
        XCTAssertNoThrow(try sut.find(text: "Apple TV 4K"))
    }

    func testPairingShowsProgressIndicator() throws {
        let device = AppleTVDevice(
            id: "test-device",
            name: "Test TV",
            host: .name("192.168.1.100", nil),
            port: 49152
        )

        let view = DeviceRow(
            device: device,
            isPaired: false,
            isPairing: true,
            onConnect: {},
            onPair: {},
            onUnpair: {}
        )

        let sut = try view.inspect()

        XCTAssertNoThrow(try sut.find(ViewType.ProgressView.self))
    }
}
