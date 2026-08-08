import XCTest
import ATVRemoteCore

final class RemoteControlPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var view: XCUIElement {
        app.otherElements[AccessibilityID.Remote.view]
    }

    var backButton: XCUIElement {
        app.buttons[AccessibilityID.Remote.backButton]
    }

    var connectionIndicator: XCUIElement {
        app.otherElements[AccessibilityID.Remote.connectionIndicator]
    }

    var deviceName: XCUIElement {
        app.staticTexts[AccessibilityID.Remote.deviceName]
    }

    var powerButton: XCUIElement {
        app.buttons[AccessibilityID.Remote.powerButton]
    }

    var touchpad: XCUIElement {
        app.otherElements[AccessibilityID.Remote.touchpad]
    }

    var menuButton: XCUIElement {
        app.buttons[AccessibilityID.Remote.menuButton]
    }

    var tvButton: XCUIElement {
        app.buttons[AccessibilityID.Remote.tvButton]
    }

    var playPauseButton: XCUIElement {
        app.buttons[AccessibilityID.Remote.playPauseButton]
    }

    var volumeUpButton: XCUIElement {
        app.buttons[AccessibilityID.Remote.volumeUpButton]
    }

    var volumeDownButton: XCUIElement {
        app.buttons[AccessibilityID.Remote.volumeDownButton]
    }

    var muteButton: XCUIElement {
        app.buttons[AccessibilityID.Remote.muteButton]
    }

    var nowPlayingSection: XCUIElement {
        app.otherElements[AccessibilityID.NowPlaying.section]
    }

    var trackTitle: XCUIElement {
        app.staticTexts[AccessibilityID.NowPlaying.trackTitle]
    }

    var trackArtist: XCUIElement {
        app.staticTexts[AccessibilityID.NowPlaying.trackArtist]
    }

    var isDisplayed: Bool {
        view.waitForExistence(timeout: 5)
    }

    var isConnected: Bool {
        connectionIndicator.exists
    }

    var currentDeviceName: String? {
        deviceName.label
    }

    func tapBack() {
        backButton.tap()
    }

    func tapPower() {
        powerButton.tap()
    }

    func tapMenu() {
        menuButton.tap()
    }

    func tapTV() {
        tvButton.tap()
    }

    func tapPlayPause() {
        playPauseButton.tap()
    }

    func tapVolumeUp() {
        volumeUpButton.tap()
    }

    func tapVolumeDown() {
        volumeDownButton.tap()
    }

    func tapMute() {
        muteButton.tap()
    }

    func tapTouchpadCenter() {
        touchpad.tap()
    }

    func swipeTouchpadUp() {
        touchpad.swipeUp()
    }

    func swipeTouchpadDown() {
        touchpad.swipeDown()
    }

    func swipeTouchpadLeft() {
        touchpad.swipeLeft()
    }

    func swipeTouchpadRight() {
        touchpad.swipeRight()
    }

    func longPressPower(duration: TimeInterval = 0.7) {
        powerButton.press(forDuration: duration)
    }

    func longPressMenu(duration: TimeInterval = 0.7) {
        menuButton.press(forDuration: duration)
    }

    func longPressTV(duration: TimeInterval = 0.7) {
        tvButton.press(forDuration: duration)
    }

    func longPressPlayPause(duration: TimeInterval = 0.7) {
        playPauseButton.press(forDuration: duration)
    }
}
