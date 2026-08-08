import Foundation

public struct TestConfiguration {
    public var useMocks: Bool = false
    public var mockScenario: MockScenario = .default
    public var preloadPairedDevice: Bool = false
    public var simulateSlowNetwork: Bool = false
    public var simulateConnectionFailure: Bool = false
    public var simulatePairingFailure: Bool = false
    public var mockSubscribed: Bool = false

    public enum MockScenario: String {
        case `default`
        case noDevices
        case multipleDevices
        case prePaired
        case connectionError
        case pairingError
        case slowNetwork
    }

    public init() {}

    public static func fromLaunchArguments() -> TestConfiguration {
        var config = TestConfiguration()
        let arguments = ProcessInfo.processInfo.arguments

        print("🔧 TestConfiguration: arguments = \(arguments)")

        if arguments.contains("-UITesting") || arguments.contains("-useMocks") {
            config.useMocks = true
            print("🔧 TestConfiguration: useMocks = true")
        } else {
            print("🔧 TestConfiguration: useMocks = false (no -UITesting or -useMocks found)")
        }

        if let scenarioIndex = arguments.firstIndex(of: "-mockScenario"),
           scenarioIndex + 1 < arguments.count,
           let scenario = MockScenario(rawValue: arguments[scenarioIndex + 1]) {
            config.mockScenario = scenario
        }

        if arguments.contains("-prePaired") {
            config.preloadPairedDevice = true
        }

        if arguments.contains("-slowNetwork") {
            config.simulateSlowNetwork = true
        }

        if arguments.contains("-connectionFailure") {
            config.simulateConnectionFailure = true
        }

        if arguments.contains("-pairingFailure") {
            config.simulatePairingFailure = true
        }

        if arguments.contains("-mockSubscribed") {
            config.mockSubscribed = true
        }

        return config
    }
}
