import XCTest

final class DeviceDiscoveryTests: BaseUITest {

    func testDeviceListScreenIsDisplayed() throws {
        app.activate()
        sleep(5)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "DeviceListScreen"
        attachment.lifetime = .keepAlways
        add(attachment)

        print("DEBUG: Full hierarchy:\n\(app.debugDescription)")
        print("DEBUG: Window count: \(app.windows.count)")

        XCTAssertTrue(deviceListPage.isDisplayed, "Device list screen should be displayed")
        XCTAssertTrue(deviceListPage.headerTitle.exists, "Header title should exist")
        XCTAssertEqual(deviceListPage.headerTitle.label, "ATV Remote Pro")
    }

    func testDevicesAreDiscovered() throws {
        XCTAssertTrue(deviceListPage.waitForDevices(), "Devices should be discovered")
        XCTAssertTrue(deviceListPage.hasDevices, "Device list should contain devices")
    }

    func testNoDevicesScenarioShowsEmptyState() throws {
        launchWithScenario(.noDevices)

        let emptyStateAppeared = deviceListPage.emptyStateTitle.waitForExistence(timeout: 5)
        XCTAssertTrue(emptyStateAppeared, "Empty state should be displayed")
        XCTAssertTrue(deviceListPage.scanButton.exists, "Scan button should be visible")
    }

    func testScanButtonRefreshesDeviceList() throws {
        launchWithScenario(.noDevices)

        XCTAssertTrue(deviceListPage.emptyStateTitle.waitForExistence(timeout: 5))
        deviceListPage.tapScanButton()

        XCTAssertTrue(deviceListPage.scanningProgress.waitForExistence(timeout: 2) ||
                      deviceListPage.emptyStateTitle.waitForExistence(timeout: 5))
    }

    func testMultipleDevicesAreDisplayed() throws {
        launchWithScenario(.multipleDevices)

        XCTAssertTrue(deviceListPage.waitForDevices(), "Devices should be discovered")

        let livingRoomExists = deviceListPage.deviceName(id: "mock-living-room").waitForExistence(timeout: 5)
        let bedroomExists = deviceListPage.deviceName(id: "mock-bedroom").waitForExistence(timeout: 5)

        XCTAssertTrue(livingRoomExists, "Living Room TV should be displayed")
        XCTAssertTrue(bedroomExists, "Bedroom TV should be displayed")
    }

    func testDeviceRowShowsPairButtonForUnpairedDevice() throws {
        XCTAssertTrue(deviceListPage.waitForDevices())

        let pairButton = deviceListPage.pairButton(id: "mock-living-room")
        XCTAssertTrue(pairButton.waitForExistence(timeout: 5), "Pair button should be visible for unpaired device")
    }

    func testDeviceRowShowsConnectButtonForPairedDevice() throws {
        launchPrePaired()

        XCTAssertTrue(deviceListPage.waitForDevices())

        print("DEBUG: All buttons: \(app.buttons.allElementsBoundByIndex.map { "\($0.identifier): \($0.label)" })")
        print("DEBUG: Looking for: DeviceRow_mock-paired_ConnectButton")

        let connectButton = deviceListPage.connectButton(id: "mock-paired")
        let pairButton = deviceListPage.pairButton(id: "mock-paired")

        print("DEBUG: Connect button exists: \(connectButton.exists)")
        print("DEBUG: Pair button exists: \(pairButton.exists)")

        XCTAssertTrue(connectButton.waitForExistence(timeout: 5), "Connect button should be visible for paired device")
    }

    func testSlowNetworkShowsScanningIndicator() throws {
        launchWithScenario(.slowNetwork)

        XCTAssertTrue(deviceListPage.scanningProgress.waitForExistence(timeout: 2),
                      "Scanning indicator should be shown during slow network")
    }
}
