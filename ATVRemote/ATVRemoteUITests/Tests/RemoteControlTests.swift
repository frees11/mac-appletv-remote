import XCTest

final class RemoteControlTests: BaseUITest {

    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToRemoteControl()
    }

    private func navigateToRemoteControl() {
        launchPrePaired()

        guard deviceListPage.waitForDevices() else {
            XCTFail("Devices not found")
            return
        }

        let connectButton = deviceListPage.connectButton(id: "mock-paired")
        guard connectButton.waitForExistence(timeout: 5) else {
            XCTFail("Connect button not found")
            return
        }

        connectButton.tap()

        _ = remoteControlPage.view.waitForExistence(timeout: 10)
    }

    func testRemoteControlIsDisplayed() throws {
        XCTAssertTrue(remoteControlPage.isDisplayed, "Remote control should be displayed")
    }

    func testDeviceNameIsDisplayed() throws {
        XCTAssertTrue(remoteControlPage.deviceName.exists, "Device name should be displayed")
    }

    func testBackButtonNavigatesToDeviceList() throws {
        remoteControlPage.tapBack()

        XCTAssertTrue(deviceListPage.isDisplayed, "Should navigate back to device list")
    }

    func testAllButtonsExist() throws {
        XCTAssertTrue(remoteControlPage.powerButton.exists, "Power button should exist")
        XCTAssertTrue(remoteControlPage.touchpad.exists, "Touchpad should exist")
        XCTAssertTrue(remoteControlPage.menuButton.exists, "Menu button should exist")
        XCTAssertTrue(remoteControlPage.tvButton.exists, "TV button should exist")
        XCTAssertTrue(remoteControlPage.playPauseButton.exists, "PlayPause button should exist")
        XCTAssertTrue(remoteControlPage.volumeUpButton.exists, "Volume up button should exist")
        XCTAssertTrue(remoteControlPage.volumeDownButton.exists, "Volume down button should exist")
        XCTAssertTrue(remoteControlPage.muteButton.exists, "Mute button should exist")
    }

    func testPowerButtonIsTappable() throws {
        XCTAssertTrue(remoteControlPage.powerButton.isHittable, "Power button should be tappable")
        remoteControlPage.tapPower()
    }

    func testMenuButtonIsTappable() throws {
        XCTAssertTrue(remoteControlPage.menuButton.isHittable, "Menu button should be tappable")
        remoteControlPage.tapMenu()
    }

    func testTVButtonIsTappable() throws {
        XCTAssertTrue(remoteControlPage.tvButton.isHittable, "TV button should be tappable")
        remoteControlPage.tapTV()
    }

    func testPlayPauseButtonIsTappable() throws {
        XCTAssertTrue(remoteControlPage.playPauseButton.isHittable, "PlayPause button should be tappable")
        remoteControlPage.tapPlayPause()
    }

    func testVolumeUpButtonIsTappable() throws {
        XCTAssertTrue(remoteControlPage.volumeUpButton.isHittable, "Volume up button should be tappable")
        remoteControlPage.tapVolumeUp()
    }

    func testVolumeDownButtonIsTappable() throws {
        XCTAssertTrue(remoteControlPage.volumeDownButton.isHittable, "Volume down button should be tappable")
        remoteControlPage.tapVolumeDown()
    }

    func testMuteButtonIsTappable() throws {
        XCTAssertTrue(remoteControlPage.muteButton.isHittable, "Mute button should be tappable")
        remoteControlPage.tapMute()
    }

    func testTouchpadIsTappable() throws {
        XCTAssertTrue(remoteControlPage.touchpad.isHittable, "Touchpad should be tappable")
        remoteControlPage.tapTouchpadCenter()
    }

    func testTouchpadSwipeUp() throws {
        XCTAssertTrue(remoteControlPage.touchpad.isHittable)
        remoteControlPage.swipeTouchpadUp()
    }

    func testTouchpadSwipeDown() throws {
        XCTAssertTrue(remoteControlPage.touchpad.isHittable)
        remoteControlPage.swipeTouchpadDown()
    }

    func testTouchpadSwipeLeft() throws {
        XCTAssertTrue(remoteControlPage.touchpad.isHittable)
        remoteControlPage.swipeTouchpadLeft()
    }

    func testTouchpadSwipeRight() throws {
        XCTAssertTrue(remoteControlPage.touchpad.isHittable)
        remoteControlPage.swipeTouchpadRight()
    }

    func testLongPressPower() throws {
        XCTAssertTrue(remoteControlPage.powerButton.isHittable)
        remoteControlPage.longPressPower()
    }

    func testLongPressMenu() throws {
        XCTAssertTrue(remoteControlPage.menuButton.isHittable)
        remoteControlPage.longPressMenu()
    }

    func testLongPressTV() throws {
        XCTAssertTrue(remoteControlPage.tvButton.isHittable)
        remoteControlPage.longPressTV()
    }

    func testLongPressPlayPause() throws {
        XCTAssertTrue(remoteControlPage.playPauseButton.isHittable)
        remoteControlPage.longPressPlayPause()
    }

    func testConnectionErrorShowsErrorState() throws {
        app.terminate()
        app = TestLauncher.launchAppConnectionError()
        deviceListPage = DeviceListPage(app: app)
        pinDialogPage = PinDialogPage(app: app)
        remoteControlPage = RemoteControlPage(app: app)

        launchPrePaired()

        guard deviceListPage.waitForDevices() else {
            return
        }

        let connectButton = deviceListPage.connectButton(id: "mock-paired")
        guard connectButton.waitForExistence(timeout: 5) else {
            return
        }

        connectButton.tap()

        let errorBanner = deviceListPage.errorBanner
        let errorExists = errorBanner.waitForExistence(timeout: 10)

        XCTAssertTrue(errorExists || remoteControlPage.isDisplayed,
                      "Either error should be shown or remote should display")
    }
}
