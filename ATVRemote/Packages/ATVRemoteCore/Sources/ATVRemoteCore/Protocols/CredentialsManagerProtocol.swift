import Foundation

public protocol CredentialsManagerProtocol: Sendable {
    func save(_ credentials: PairingCredentials) throws
    func load(for deviceId: String) throws -> PairingCredentials?
    func delete(for deviceId: String) throws
    func listAllDeviceIds() throws -> [String]
    func hasPairing(for deviceId: String) -> Bool
}
