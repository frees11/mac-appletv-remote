import XCTest
import ATVRemoteCore

enum MockScenario: String {
    case `default` = "default"
    case noDevices = "noDevices"
    case multipleDevices = "multipleDevices"
    case prePaired = "prePaired"
    case connectionError = "connectionError"
    case pairingError = "pairingError"
    case slowNetwork = "slowNetwork"
}

final class TestLauncher {
    static func launchApp(
        scenario: MockScenario = .default,
        preloadPaired: Bool = false,
        simulateSlowNetwork: Bool = false,
        simulateConnectionFailure: Bool = false,
        simulatePairingFailure: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()

        var launchArguments = ["-UITesting"]

        launchArguments.append("-mockScenario")
        launchArguments.append(scenario.rawValue)

        if preloadPaired {
            launchArguments.append("-prePaired")
        }

        if simulateSlowNetwork {
            launchArguments.append("-slowNetwork")
        }

        if simulateConnectionFailure {
            launchArguments.append("-connectionFailure")
        }

        if simulatePairingFailure {
            launchArguments.append("-pairingFailure")
        }

        app.launchArguments = launchArguments
        app.launch()

        waitForAppWindow(app)

        return app
    }

    private static func waitForAppWindow(_ app: XCUIApplication, maxAttempts: Int = 20) {
        for attempt in 0..<maxAttempts {
            app.activate()

            if app.windows.firstMatch.waitForExistence(timeout: 1) {
                return
            }

            Thread.sleep(forTimeInterval: 0.5)
            print("TestLauncher: Window not found, attempt \(attempt + 1)/\(maxAttempts)")
        }

        print("TestLauncher: Warning - Window may not be visible after \(maxAttempts) attempts")
    }

    static func launchAppWithMocks() -> XCUIApplication {
        launchApp(scenario: .default)
    }

    static func launchAppNoDevices() -> XCUIApplication {
        launchApp(scenario: .noDevices)
    }

    static func launchAppMultipleDevices() -> XCUIApplication {
        launchApp(scenario: .multipleDevices)
    }

    static func launchAppPrePaired() -> XCUIApplication {
        launchApp(scenario: .prePaired, preloadPaired: true)
    }

    static func launchAppConnectionError() -> XCUIApplication {
        launchApp(scenario: .connectionError)
    }

    static func launchAppPairingError() -> XCUIApplication {
        launchApp(scenario: .pairingError)
    }

    static func launchAppSlowNetwork() -> XCUIApplication {
        launchApp(scenario: .slowNetwork)
    }
}
