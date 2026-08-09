import Foundation
import Network
import os.log
import Combine

private let logger = Logger(subsystem: "com.atv.remote", category: "Discovery")

@MainActor
public final class DeviceDiscoveryService: ObservableObject, DeviceDiscoveryServiceProtocol {
    @Published public private(set) var devices: [AppleTVDevice] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var error: Error?
    @Published public private(set) var debugStatus: String = "Not started"

    public var changePublisher: AnyPublisher<Void, Never> {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }

    private var browser: NWBrowser?
    private var mrpBrowser: NWBrowser?
    private var pendingMRPEndpoints: [String: (NWEndpoint.Host, NWEndpoint.Port)] = [:]
    private let queue = DispatchQueue(label: "com.atv.remote.discovery")

    public init() {}

    public func startScanning() {
        guard !isScanning else {
            debugStatus = "Already scanning"
            logger.info("Already scanning, ignoring request")
            return
        }

        devices.removeAll()
        error = nil
        isScanning = true
        debugStatus = "Starting scan..."
        logger.info("Starting NWBrowser scan for _companion-link._tcp")

        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(type: "_companion-link._tcp", domain: "local.")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: descriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleBrowserState(state)
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.handleBrowseResults(results, changes: changes)
            }
        }

        browser?.start(queue: queue)
        logger.info("NWBrowser started")

        startMRPScanning()
    }

    private func startMRPScanning() {
        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(type: "_mediaremotetv._tcp", domain: "local.")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: descriptor, using: parameters)
        mrpBrowser = browser

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                for result in results {
                    self?.processMRPResult(result)
                }
            }
        }

        browser.start(queue: queue)
        logger.info("NWBrowser started for _mediaremotetv._tcp")
    }

    private func processMRPResult(_ result: NWBrowser.Result) {
        guard case .service(let name, _, _, _) = result.endpoint else {
            return
        }

        resolveEndpoint(result) { [weak self] resolvedHost, resolvedPort in
            guard let host = resolvedHost, let port = resolvedPort else {
                logger.info("MRP service for \(name) did not resolve, skipping")
                return
            }

            Task { @MainActor in
                guard let self = self else { return }
                guard let index = self.devices.firstIndex(where: { $0.name == name }) else {
                    self.pendingMRPEndpoints[name] = (host, port)
                    return
                }
                self.devices[index].mrpHost = host
                self.devices[index].mrpPort = port
                logger.info("MRP endpoint for \(name): \(host.debugDescription):\(port.rawValue)")
            }
        }
    }

    public func stopScanning() {
        browser?.cancel()
        browser = nil
        mrpBrowser?.cancel()
        mrpBrowser = nil
        pendingMRPEndpoints.removeAll()
        isScanning = false
        debugStatus = "Stopped"
        logger.info("NWBrowser stopped")
    }

    private func handleBrowserState(_ state: NWBrowser.State) {
        logger.info("Browser state: \(String(describing: state))")
        switch state {
        case .ready:
            debugStatus = "Scanning..."
            logger.info("Browser ready and scanning")
        case .failed(let error):
            debugStatus = "Error: \(error.localizedDescription)"
            self.error = error
            isScanning = false
            logger.error("Browser failed: \(error.localizedDescription)")
        case .cancelled:
            isScanning = false
            debugStatus = "Cancelled"
        case .setup:
            debugStatus = "Setting up..."
        case .waiting(let error):
            debugStatus = "Waiting: \(error.localizedDescription)"
            logger.warning("Browser waiting: \(error.localizedDescription)")
        @unknown default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        logger.info("Browse results: \(results.count) services")

        for change in changes {
            switch change {
            case .added(let result):
                logger.info("Service added: \(String(describing: result.endpoint))")
                processResult(result)
            case .removed(let result):
                logger.info("Service removed: \(String(describing: result.endpoint))")
                removeResult(result)
            case .changed(old: _, new: let result, flags: _):
                logger.info("Service changed: \(String(describing: result.endpoint))")
                processResult(result)
            case .identical:
                break
            @unknown default:
                break
            }
        }

        if devices.isEmpty && !results.isEmpty {
            debugStatus = "Processing \(results.count) service(s)..."
        } else if !devices.isEmpty {
            debugStatus = "Found \(devices.count) Apple TV(s)"
        }
    }

    private func processResult(_ result: NWBrowser.Result) {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            return
        }

        logger.info("Processing service: \(name) type: \(type) domain: \(domain)")

        var model: String?
        if case .bonjour(let txtRecord) = result.metadata {
            model = txtRecord["rpMd"]
        }

        guard AppleTVDevice.isAppleTV(model: model) else {
            logger.info("Rejecting non-Apple TV service: \(name) (rpMd=\(model ?? "absent"))")
            removeDeviceByName(name)
            return
        }

        let deviceId = "\(name).\(type)\(domain)"

        if devices.contains(where: { $0.id == deviceId }) {
            if let model = model, let idx = devices.firstIndex(where: { $0.id == deviceId }) {
                var updated = devices[idx]
                updated = AppleTVDevice(
                    id: updated.id,
                    name: updated.name,
                    host: updated.host,
                    port: updated.port,
                    endpoint: updated.endpoint,
                    interface: updated.interface,
                    model: model,
                    isPaired: updated.isPaired,
                    isConnected: updated.isConnected,
                    mrpHost: updated.mrpHost,
                    mrpPort: updated.mrpPort
                )
                devices[idx] = updated
                logger.info("Updated device model: \(name) = \(model)")
            }
            return
        }

        let serviceEndpoint = result.endpoint
        let serviceInterface = result.interfaces.first

        resolveEndpoint(result) { [weak self] resolvedHost, resolvedPort in
            Task { @MainActor in
                guard let self = self else { return }

                let mrpEndpoint = self.pendingMRPEndpoints[name]
                let device = AppleTVDevice(
                    id: deviceId,
                    name: name,
                    host: resolvedHost,
                    port: resolvedPort,
                    endpoint: serviceEndpoint,
                    interface: serviceInterface,
                    model: model,
                    isPaired: false,
                    isConnected: false,
                    mrpHost: mrpEndpoint?.0,
                    mrpPort: mrpEndpoint?.1
                )

                if !self.devices.contains(where: { $0.id == device.id }) {
                    self.devices.append(device)
                    self.debugStatus = "Found \(self.devices.count) device(s)"
                    logger.info("Added device: \(name) port \(resolvedPort?.rawValue ?? 0) (0 = unresolved, connecting via Bonjour)")
                }
            }
        }
    }

    private func removeDeviceByName(_ name: String) {
        devices.removeAll { $0.name == name }
        debugStatus = devices.isEmpty ? "Scanning..." : "Found \(devices.count) device(s)"
    }

    private func removeResult(_ result: NWBrowser.Result) {
        guard case .service(let name, _, _, _) = result.endpoint else {
            return
        }
        devices.removeAll { $0.name == name }
        debugStatus = devices.isEmpty ? "No Apple TVs found" : "Found \(devices.count) Apple TV(s)"
    }

    private final class ResolveState {
        var finished = false
    }

    /// Resolves a Bonjour result to a concrete host and port. Reports `nil` when
    /// resolution fails — callers that cannot work with a guessed endpoint (MRP)
    /// must skip the service instead of connecting somewhere meaningless.
    /// All callbacks run on `queue`, so the completion guard needs no locking.
    private func resolveEndpoint(_ result: NWBrowser.Result, completion: @escaping (NWEndpoint.Host?, NWEndpoint.Port?) -> Void) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        parameters.requiredInterface = result.interfaces.first

        if let ipOptions = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .v4
        }

        let connection = NWConnection(to: result.endpoint, using: parameters)
        let state = ResolveState()

        let finish: (NWEndpoint.Host?, NWEndpoint.Port?) -> Void = { [weak connection] host, port in
            guard !state.finished else { return }
            state.finished = true
            completion(host, port)
            connection?.cancel()
        }

        connection.stateUpdateHandler = { [weak connection] connectionState in
            switch connectionState {
            case .ready:
                if let innerEndpoint = connection?.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = innerEndpoint {
                    finish(host, port)
                } else {
                    finish(nil, nil)
                }
            case .failed, .cancelled:
                finish(nil, nil)
            default:
                break
            }
        }

        connection.start(queue: queue)

        queue.asyncAfter(deadline: .now() + 5.0) {
            finish(nil, nil)
        }
    }

    public func resolveDevice(_ device: AppleTVDevice) async throws -> (host: String, port: UInt16) {
        guard let host = device.host, let port = device.port else {
            throw DeviceDiscoveryError.resolutionFailed
        }
        if case .name(let hostname, _) = host {
            return (hostname, port.rawValue)
        }
        return (host.debugDescription, port.rawValue)
    }
}

public enum DeviceDiscoveryError: Error, LocalizedError {
    case resolutionFailed
    case timeout

    public var errorDescription: String? {
        switch self {
        case .resolutionFailed:
            return "Failed to resolve device address"
        case .timeout:
            return "Device discovery timed out"
        }
    }
}
