import SwiftUI
import ATVRemoteCore
import Combine
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if isUITesting {
            scheduleWindowActivation(attempts: 0)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.ensureWindowVisible()
            }
        }
    }

    private func scheduleWindowActivation(attempts: Int) {
        guard attempts < 50 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.activateFirstWindow() {
                return
            }
            self.scheduleWindowActivation(attempts: attempts + 1)
        }
    }

    private func activateFirstWindow() -> Bool {
        let contentWindows = NSApp.windows.filter { window in
            window.contentView != nil &&
            !window.title.isEmpty &&
            window.canBecomeKey
        }

        guard let window = contentWindows.first else {
            return false
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private func ensureWindowVisible() {
        if NSApp.windows.isEmpty || NSApp.windows.allSatisfy({ !$0.isVisible }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.ensureWindowVisible()
            }
            return
        }

        for window in NSApp.windows where window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if isUITesting {
            scheduleWindowActivation(attempts: 0)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.ensureWindowVisible()
            }
        }
    }
}

@main
struct ATVRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState: AppState

    init() {
        let factory = ServiceFactory()
        _appState = StateObject(wrappedValue: AppState(factory: factory))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 800)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedDevice: AppleTVDevice?
    @Published var isConnected: Bool = false
    @Published var pairingError: String?
    @Published var isPairing: Bool = false

    /// Drives the App Review demo: without an Apple TV on the network the app
    /// has nothing to show, so it can run against the mock services instead.
    @Published private(set) var isDemoMode: Bool = false

    let credentialsManager: any CredentialsManagerProtocol
    let pairingService: any PairingServiceProtocol
    let subscriptionService: any SubscriptionServiceProtocol

    var discoveryService: any DeviceDiscoveryServiceProtocol {
        isDemoMode ? demoDiscoveryService : liveDiscoveryService
    }

    var connectionService: any ConnectionServiceProtocol {
        isDemoMode ? demoConnectionService : liveConnectionService
    }

    private let liveDiscoveryService: any DeviceDiscoveryServiceProtocol
    private let liveConnectionService: any ConnectionServiceProtocol
    private let demoDiscoveryService: MockDeviceDiscoveryService
    private let demoConnectionService: MockConnectionService

    private var pinCompletionHandler: ((String) async throws -> PairingCredentials)?
    private var cancellables = Set<AnyCancellable>()

    convenience init() {
        self.init(factory: ServiceFactory())
    }

    init(factory: ServiceFactory) {
        let credentials = factory.createCredentialsManager()
        self.credentialsManager = credentials
        self.liveDiscoveryService = factory.createDiscoveryService()
        self.pairingService = factory.createPairingService()
        self.liveConnectionService = factory.createConnectionService(credentialsManager: credentials)
        self.subscriptionService = factory.createSubscriptionService()

        let demoDiscovery = MockDeviceDiscoveryService()
        demoDiscovery.mockDevices = [MockData.livingRoomTV, MockData.bedroomTV]
        self.demoDiscoveryService = demoDiscovery

        let demoConnection = MockConnectionService(credentialsManager: credentials)
        demoConnection.shouldRequirePairing = false
        self.demoConnectionService = demoConnection

        setupObservation()
        subscriptionService.start()
    }

    func setDemoMode(_ enabled: Bool) {
        guard enabled != isDemoMode else { return }
        disconnectFromDevice()
        isDemoMode = enabled
        objectWillChange.send()
    }

    private func setupObservation() {
        let publishers: [AnyPublisher<Void, Never>] = [
            liveDiscoveryService.changePublisher,
            liveConnectionService.changePublisher,
            demoDiscoveryService.changePublisher,
            demoConnectionService.changePublisher,
            subscriptionService.changePublisher
        ]

        for publisher in publishers {
            publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }

    func isPaired(_ device: AppleTVDevice) -> Bool {
        credentialsManager.hasPairing(for: device.id)
    }

    func connectToDevice(_ device: AppleTVDevice) async throws {
        selectedDevice = device
        try await connectionService.connect(to: device)
        isConnected = true
    }

    func disconnectFromDevice() {
        connectionService.disconnect()
        isConnected = false
        selectedDevice = nil
    }

    func startPairing(device: AppleTVDevice) async throws {
        isPairing = true
        pairingError = nil
        do {
            pinCompletionHandler = try await pairingService.startPairing(device: device)
        } catch {
            isPairing = false
            pairingError = error.localizedDescription
            throw error
        }
    }

    func completePairing(pin: String) async throws {
        guard let handler = pinCompletionHandler else {
            throw PairingError.connectionFailed
        }

        do {
            let credentials = try await handler(pin)
            try credentialsManager.save(credentials)
            isPairing = false
            pairingError = nil
            pinCompletionHandler = nil
        } catch {
            isPairing = false
            pairingError = error.localizedDescription
            pinCompletionHandler = nil
            throw error
        }
    }

    func cancelPairing() {
        pairingService.cancel()
        isPairing = false
        pairingError = nil
        pinCompletionHandler = nil
    }

    func unpair(_ device: AppleTVDevice) {
        do {
            try credentialsManager.delete(for: device.id)
            objectWillChange.send()
        } catch {
            pairingError = "Failed to unpair: \(error.localizedDescription)"
        }
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isMovableByWindowBackground = true
        window.titlebarSeparatorStyle = .none
        window.titlebarAppearsTransparent = true
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    private var hasAccess: Bool {
        appState.subscriptionService.status.isActive || appState.isDemoMode
    }

    var body: some View {
        Group {
            if !appState.subscriptionService.status.isResolved {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: "#1c1c1e"))
            } else if !hasAccess {
                PaywallView()
            } else {
                VStack(spacing: 0) {
                    if appState.isDemoMode {
                        DemoModeBanner()
                    }
                    if let device = appState.selectedDevice, appState.isConnected {
                        RemoteControlView(device: device)
                    } else {
                        DeviceListView()
                    }
                }
            }
        }
        .frame(width: 400, height: 800)
        .background(Color(hex: "#1c1c1e"))
        .background(WindowConfigurator())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("MainContent")
    }
}
