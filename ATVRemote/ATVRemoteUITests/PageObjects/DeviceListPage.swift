import XCTest
import ATVRemoteCore

final class DeviceListPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var headerIcon: XCUIElement {
        app.images[AccessibilityID.DeviceList.headerIcon]
    }

    var headerTitle: XCUIElement {
        app.staticTexts[AccessibilityID.DeviceList.headerTitle]
    }

    var scanningProgress: XCUIElement {
        app.progressIndicators[AccessibilityID.DeviceList.scanningProgress]
    }

    var emptyStateIcon: XCUIElement {
        app.images[AccessibilityID.DeviceList.emptyStateIcon]
    }

    var emptyStateTitle: XCUIElement {
        app.staticTexts[AccessibilityID.DeviceList.emptyStateTitle]
    }

    var scanButton: XCUIElement {
        app.buttons[AccessibilityID.DeviceList.scanButton]
    }

    var scrollView: XCUIElement {
        app.scrollViews[AccessibilityID.DeviceList.scrollView]
    }

    var errorBanner: XCUIElement {
        app.staticTexts[AccessibilityID.DeviceList.errorBanner]
    }

    func deviceRow(id: String) -> XCUIElement {
        app.otherElements[AccessibilityID.DeviceList.deviceRow(id)]
    }

    func deviceName(id: String) -> XCUIElement {
        app.staticTexts[AccessibilityID.DeviceList.deviceName(id)]
    }

    func pairButton(id: String) -> XCUIElement {
        app.buttons[AccessibilityID.DeviceList.pairButton(id)]
    }

    func connectButton(id: String) -> XCUIElement {
        let byAccessibilityId = app.buttons[AccessibilityID.DeviceList.connectButton(id)]
        if byAccessibilityId.exists {
            return byAccessibilityId
        }
        let buttonWithRowId = app.buttons[AccessibilityID.DeviceList.deviceRow(id)]
        if buttonWithRowId.exists && buttonWithRowId.label == "Connect" {
            return buttonWithRowId
        }
        return byAccessibilityId
    }

    func unpairButton(id: String) -> XCUIElement {
        app.buttons[AccessibilityID.DeviceList.unpairButton(id)]
    }

    var isDisplayed: Bool {
        headerTitle.waitForExistence(timeout: 5)
    }

    var isScanning: Bool {
        scanningProgress.exists
    }

    var isEmpty: Bool {
        emptyStateTitle.exists
    }

    var hasDevices: Bool {
        scrollView.exists && !isEmpty
    }

    func waitForDevices(timeout: TimeInterval = 5) -> Bool {
        scrollView.waitForExistence(timeout: timeout)
    }

    func tapScanButton() {
        scanButton.tap()
    }

    func tapPairButton(deviceId: String) {
        pairButton(id: deviceId).tap()
    }

    func tapConnectButton(deviceId: String) {
        connectButton(id: deviceId).tap()
    }
}
