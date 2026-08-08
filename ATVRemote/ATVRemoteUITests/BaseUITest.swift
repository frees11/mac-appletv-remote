import XCTest

class BaseUITest: XCTestCase {
    var app: XCUIApplication!

    var deviceListPage: DeviceListPage!
    var pinDialogPage: PinDialogPage!
    var remoteControlPage: RemoteControlPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = TestLauncher.launchAppWithMocks()

        let windowExists = app.windows.firstMatch.waitForExistence(timeout: 10)
        if !windowExists {
            print("WARNING: No window found after launch. Windows count: \(app.windows.count)")
            print("App state: \(app.state.rawValue)")
        }

        deviceListPage = DeviceListPage(app: app)
        pinDialogPage = PinDialogPage(app: app)
        remoteControlPage = RemoteControlPage(app: app)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
        deviceListPage = nil
        pinDialogPage = nil
        remoteControlPage = nil
    }

    func launchWithScenario(_ scenario: MockScenario) {
        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)
        app = TestLauncher.launchApp(scenario: scenario)
        deviceListPage = DeviceListPage(app: app)
        pinDialogPage = PinDialogPage(app: app)
        remoteControlPage = RemoteControlPage(app: app)
    }

    func launchPrePaired() {
        app.terminate()
        Thread.sleep(forTimeInterval: 0.5)
        app = TestLauncher.launchAppPrePaired()
        deviceListPage = DeviceListPage(app: app)
        pinDialogPage = PinDialogPage(app: app)
        remoteControlPage = RemoteControlPage(app: app)
    }
}
