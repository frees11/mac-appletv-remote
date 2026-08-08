import Foundation
import Network

public struct AppleTVDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let host: NWEndpoint.Host
    public let port: NWEndpoint.Port
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
        host: NWEndpoint.Host,
        port: NWEndpoint.Port,
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
        self.model = model
        self.isPaired = isPaired
        self.isConnected = isConnected
        self.mrpHost = mrpHost
        self.mrpPort = mrpPort
    }

    public var ipAddress: String? {
        switch host {
        case .ipv4(let address):
            return String("\(address)".prefix(while: { $0 != "%" }))
        case .ipv6(let address):
            return String("\(address)".prefix(while: { $0 != "%" }))
        case .name:
            return nil
        @unknown default:
            return nil
        }
    }

    public var modelDisplayName: String? {
        guard let model else { return nil }
        return AppleTVDevice.marketingNames[model] ?? model
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
