import Foundation

@MainActor
public final class ServiceFactory {
    private let config: TestConfiguration

    public init(config: TestConfiguration = .fromLaunchArguments()) {
        self.config = config
        #if DEBUG
        print("🔧 ServiceFactory init: useMocks = \(config.useMocks)")
        #endif
    }

    public var useMocks: Bool {
        return config.useMocks
    }

    public func createCredentialsManager() -> any CredentialsManagerProtocol {
        if useMocks {
            let mock = MockCredentialsManager()
            NSLog("🔧 createCredentialsManager: scenario=\(config.mockScenario.rawValue), preloadPaired=\(config.preloadPairedDevice)")
            if config.mockScenario == .prePaired {
                NSLog("🔧 Preloading pairedCredentials for device: \(MockData.pairedCredentials.deviceId)")
                mock.preloadCredentials(MockData.pairedCredentials)
                NSLog("🔧 Verify hasPairing: \(mock.hasPairing(for: MockData.pairedCredentials.deviceId))")
            } else if config.preloadPairedDevice {
                NSLog("🔧 Preloading mockCredentials for device: \(MockData.mockCredentials.deviceId)")
                mock.preloadCredentials(MockData.mockCredentials)
            }
            return mock
        }
        return CredentialsManager()
    }

    public func createDiscoveryService() -> any DeviceDiscoveryServiceProtocol {
        if useMocks {
            let mock = MockDeviceDiscoveryService()
            configureMockDiscovery(mock)
            return mock
        }
        return DeviceDiscoveryService()
    }

    public func createConnectionService(credentialsManager: any CredentialsManagerProtocol) -> any ConnectionServiceProtocol {
        if useMocks {
            let mock = MockConnectionService(credentialsManager: credentialsManager)
            configureMockConnection(mock)
            return mock
        }
        return ConnectionService(credentialsManager: credentialsManager as! CredentialsManager)
    }

    /// `-mockSubscribed` works on its own, so the real discovery and connection
    /// services can be exercised without a live subscription blocking the way.
    public func createSubscriptionService() -> any SubscriptionServiceProtocol {
        guard useMocks || config.mockSubscribed else {
            return SubscriptionService()
        }
        let status: SubscriptionStatus = config.mockSubscribed
            ? .subscribed(productID: SubscriptionProductID.yearly, expirationDate: MockData.subscriptionExpiration)
            : .notSubscribed
        return MockSubscriptionService(status: status)
    }

    public func createPairingService() -> any PairingServiceProtocol {
        if useMocks {
            let mock = MockPairingService()
            configureMockPairing(mock)
            return mock
        }
        return PairingService()
    }

    private func configureMockDiscovery(_ mock: MockDeviceDiscoveryService) {
        print("🔧 configureMockDiscovery: scenario = \(config.mockScenario)")
        switch config.mockScenario {
        case .noDevices:
            mock.mockDevices = []
        case .multipleDevices:
            mock.mockDevices = [MockData.livingRoomTV, MockData.bedroomTV]
        case .prePaired:
            mock.mockDevices = [MockData.pairedTV]
        case .connectionError, .pairingError, .default:
            mock.mockDevices = [MockData.livingRoomTV]
        case .slowNetwork:
            mock.mockDevices = [MockData.livingRoomTV]
            mock.scanDelay = 3.0
        }
        print("🔧 configureMockDiscovery: mock.mockDevices.count = \(mock.mockDevices.count)")

        if config.simulateSlowNetwork { mock.scanDelay = 3.0 }
    }

    private func configureMockConnection(_ mock: MockConnectionService) {
        if config.simulateConnectionFailure || config.mockScenario == .connectionError {
            mock.shouldFailConnection = true
        }
        if config.simulateSlowNetwork { mock.connectionDelay = 2.0 }
        mock.shouldRequirePairing = true
    }

    private func configureMockPairing(_ mock: MockPairingService) {
        if config.simulatePairingFailure || config.mockScenario == .pairingError {
            mock.shouldFailPairing = true
        }
        if config.simulateSlowNetwork { mock.pairingDelay = 2.0 }
    }
}
