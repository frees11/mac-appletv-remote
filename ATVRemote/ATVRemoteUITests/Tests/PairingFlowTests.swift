import XCTest

final class PairingFlowTests: BaseUITest {

    func testPairButtonOpensPinDialog() throws {
        XCTAssertTrue(deviceListPage.waitForDevices())

        deviceListPage.tapPairButton(deviceId: "mock-living-room")

        XCTAssertTrue(pinDialogPage.isDisplayed, "PIN dialog should be displayed after tapping Pair")
    }

    func testCancelButtonClosesPinDialog() throws {
        XCTAssertTrue(deviceListPage.waitForDevices())

        deviceListPage.tapPairButton(deviceId: "mock-living-room")
        XCTAssertTrue(pinDialogPage.isDisplayed)

        pinDialogPage.tapCancel()

        XCTAssertTrue(pinDialogPage.waitForDismissal(), "PIN dialog should be dismissed")
        XCTAssertTrue(deviceListPage.isDisplayed, "Device list should be visible again")
    }

    func testCorrectPinCompletedPairing() throws {
        XCTAssertTrue(deviceListPage.waitForDevices())

        deviceListPage.tapPairButton(deviceId: "mock-living-room")
        XCTAssertTrue(pinDialogPage.isDisplayed)

        pinDialogPage.enterPin("1234")
        pinDialogPage.tapConnect()

        XCTAssertTrue(pinDialogPage.waitForDismissal(timeout: 10), "PIN dialog should close after successful pairing")

        let connectButton = deviceListPage.connectButton(id: "mock-living-room")
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5), "Connect button should appear for newly paired device")
    }

    func testConnectButtonIsDisabledWithInvalidPin() throws {
        XCTAssertTrue(deviceListPage.waitForDevices())

        deviceListPage.tapPairButton(deviceId: "mock-living-room")
        XCTAssertTrue(pinDialogPage.isDisplayed)

        pinDialogPage.enterPin("12")

        XCTAssertFalse(pinDialogPage.connectButton.isEnabled, "Connect button should be disabled for invalid PIN length")
    }

    func testPairingErrorShowsErrorMessage() throws {
        launchWithScenario(.pairingError)

        XCTAssertTrue(deviceListPage.waitForDevices())

        deviceListPage.tapPairButton(deviceId: "mock-living-room")

        let errorBanner = deviceListPage.errorBanner
        XCTAssertTrue(errorBanner.waitForExistence(timeout: 10), "Error message should be displayed on pairing failure")
    }

    func testWrongPinShowsError() throws {
        XCTAssertTrue(deviceListPage.waitForDevices())

        deviceListPage.tapPairButton(deviceId: "mock-living-room")
        XCTAssertTrue(pinDialogPage.isDisplayed)

        pinDialogPage.enterPin("9999")
        pinDialogPage.tapConnect()

        let errorText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Invalid'"))
        XCTAssertTrue(errorText.firstMatch.waitForExistence(timeout: 5), "Error should be shown for wrong PIN")
    }

    func testSuccessfulPairingNavigatesToRemote() throws {
        XCTAssertTrue(deviceListPage.waitForDevices())

        deviceListPage.tapPairButton(deviceId: "mock-living-room")
        XCTAssertTrue(pinDialogPage.isDisplayed)

        pinDialogPage.enterPin("1234")
        pinDialogPage.tapConnect()

        XCTAssertTrue(pinDialogPage.waitForDismissal(timeout: 10))

        let connectButton = deviceListPage.connectButton(id: "mock-living-room")
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5))

        connectButton.tap()

        XCTAssertTrue(remoteControlPage.isDisplayed, "Remote control should be displayed after connecting")
    }
}
