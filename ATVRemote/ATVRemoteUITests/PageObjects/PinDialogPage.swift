import XCTest
import ATVRemoteCore

final class PinDialogPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var container: XCUIElement {
        app.sheets[AccessibilityID.PinDialog.container]
    }

    var textField: XCUIElement {
        app.textFields[AccessibilityID.PinDialog.textField]
    }

    var cancelButton: XCUIElement {
        app.buttons[AccessibilityID.PinDialog.cancelButton]
    }

    var connectButton: XCUIElement {
        app.buttons[AccessibilityID.PinDialog.connectButton]
    }

    var isDisplayed: Bool {
        textField.waitForExistence(timeout: 5)
    }

    func enterPin(_ pin: String) {
        textField.tap()
        textField.typeText(pin)
    }

    func tapConnect() {
        connectButton.tap()
    }

    func tapCancel() {
        cancelButton.tap()
    }

    func waitForDismissal(timeout: TimeInterval = 5) -> Bool {
        !textField.waitForExistence(timeout: timeout)
    }
}
