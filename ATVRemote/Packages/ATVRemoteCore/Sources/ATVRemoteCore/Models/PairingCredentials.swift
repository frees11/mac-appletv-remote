import Foundation

public struct PairingCredentials: Codable, Sendable, Equatable {
    public let deviceId: String
    public let ltpk: Data
    public let ltsk: Data
    public let peerPublicKey: Data
    public let identifier: Data
    public let pairingId: String
    public let createdAt: Date

    public init(
        deviceId: String,
        ltpk: Data,
        ltsk: Data,
        peerPublicKey: Data,
        identifier: Data,
        pairingId: String,
        createdAt: Date = Date()
    ) {
        self.deviceId = deviceId
        self.ltpk = ltpk
        self.ltsk = ltsk
        self.peerPublicKey = peerPublicKey
        self.identifier = identifier
        self.pairingId = pairingId
        self.createdAt = createdAt
    }
}
