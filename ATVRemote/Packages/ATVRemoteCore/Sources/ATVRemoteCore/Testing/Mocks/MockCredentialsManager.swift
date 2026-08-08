import Foundation

public final class MockCredentialsManager: CredentialsManagerProtocol, @unchecked Sendable {
    private var storage: [String: PairingCredentials] = [:]
    private let lock = NSLock()

    public var shouldFailSave: Bool = false
    public var shouldFailLoad: Bool = false
    public var shouldFailDelete: Bool = false

    public init() {}

    public init(preloadedCredentials: [PairingCredentials]) {
        for cred in preloadedCredentials {
            storage[cred.deviceId] = cred
        }
    }

    public func save(_ credentials: PairingCredentials) throws {
        if shouldFailSave { throw CredentialsError.saveFailed(-1) }
        lock.lock()
        defer { lock.unlock() }
        storage[credentials.deviceId] = credentials
    }

    public func load(for deviceId: String) throws -> PairingCredentials? {
        if shouldFailLoad { throw CredentialsError.loadFailed(-1) }
        lock.lock()
        defer { lock.unlock() }
        return storage[deviceId]
    }

    public func delete(for deviceId: String) throws {
        if shouldFailDelete { throw CredentialsError.deleteFailed(-1) }
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: deviceId)
    }

    public func listAllDeviceIds() throws -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.keys)
    }

    public func hasPairing(for deviceId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[deviceId] != nil
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }

    public func preloadCredentials(_ credentials: PairingCredentials) {
        lock.lock()
        defer { lock.unlock() }
        storage[credentials.deviceId] = credentials
    }
}
