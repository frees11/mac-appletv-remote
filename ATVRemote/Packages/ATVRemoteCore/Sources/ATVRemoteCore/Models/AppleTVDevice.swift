import Foundation
import Network

public struct AppleTVDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    /// Best-effort address for display only. Bonjour resolution can fail without
    /// making the device unreachable, so these stay optional and never feed a
    /// connection — `connectionEndpoint` does.
    public let host: NWEndpoint.Host?
    public let port: NWEndpoint.Port?

    /// The Bonjour service as advertised. Connecting through it lets the network
    /// stack resolve the address itself, so no host or port has to be guessed.
    public let endpoint: NWEndpoint?

    /// Interface the service was discovered on. Connections must be scoped to it:
    /// with a VPN as the primary route, an unscoped connection binds to the VPN
    /// interface where the Apple TV does not exist and waits forever.
    public let interface: NWInterface?

    public let model: String?
    public var isPaired: Bool
    public var isConnected: Bool

    /// MediaRemote endpoint, advertised separately from Companion as
    /// `_mediaremotetv._tcp`. Only devices exposing direct MRP report it.
    public var mrpHost: NWEndpoint.Host?
    public var mrpPort: NWEndpoint.Port?

    public init(
        id: String,
        name: String,
        host: NWEndpoint.Host? = nil,
        port: NWEndpoint.Port? = nil,
        endpoint: NWEndpoint? = nil,
        interface: NWInterface? = nil,
        model: String? = nil,
        isPaired: Bool = false,
        isConnected: Bool = false,
        mrpHost: NWEndpoint.Host? = nil,
        mrpPort: NWEndpoint.Port? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.endpoint = endpoint
        self.interface = interface
        self.model = model
        self.isPaired = isPaired
        self.isConnected = isConnected
        self.mrpHost = mrpHost
        self.mrpPort = mrpPort
    }

    /// Endpoint every connection must go through. Prefers the advertised Bonjour
    /// service; falls back to a resolved address only when one is actually known.
    public var connectionEndpoint: NWEndpoint? {
        if let endpoint {
            return endpoint
        }
        guard let host, let port else { return nil }
        return .hostPort(host: host, port: port)
    }

    public var ipAddress: String? {
        switch host {
        case .ipv4(let address):
            return String("\(address)".prefix(while: { $0 != "%" }))
        case .ipv6(let address):
            return String("\(address)".prefix(while: { $0 != "%" }))
        case .name, .none:
            return nil
        @unknown default:
            return nil
        }
    }

    public var modelDisplayName: String? {
        guard let model else { return nil }
        return AppleTVDevice.marketingNames[model] ?? model
    }

    /// `_companion-link._tcp` is a Continuity service every Apple device publishes.
    /// Only Apple TVs carry an `rpMd` model in the TXT record — Macs and iPads omit
    /// the key entirely — so an absent model means "not an Apple TV", never "unknown".
    public static func isAppleTV(model: String?) -> Bool {
        guard let model else { return false }
        return model.hasPrefix("AppleTV")
    }

    private static let marketingNames: [String: String] = [
        "AppleTV2,1": "Apple TV (2nd gen)",
        "AppleTV3,1": "Apple TV (3rd gen)",
        "AppleTV3,2": "Apple TV (3rd gen)",
        "AppleTV5,3": "Apple TV HD",
        "AppleTV6,2": "Apple TV 4K",
        "AppleTV11,1": "Apple TV 4K (2nd gen)",
        "AppleTV14,1": "Apple TV 4K (3rd gen)",
    ]

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AppleTVDevice, rhs: AppleTVDevice) -> Bool {
        lhs.id == rhs.id
    }
}
