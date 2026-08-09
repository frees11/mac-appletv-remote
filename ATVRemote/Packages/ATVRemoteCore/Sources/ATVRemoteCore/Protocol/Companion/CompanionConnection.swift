import Foundation
import Network

public enum CompanionConnectionError: Error, LocalizedError {
    case connectionFailed
    case unresolvedEndpoint
    case timeout
    case disconnected
    case invalidFrame
    case sendFailed
    case receiveFailed
    case pairVerifyFailed
    case encryptionFailed
    case decryptionFailed
    case notEncrypted

    public var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Failed to connect to Apple TV"
        case .unresolvedEndpoint: return "Apple TV has no reachable address yet"
        case .timeout: return "Connection timed out"
        case .disconnected: return "Disconnected from Apple TV"
        case .invalidFrame: return "Invalid frame received"
        case .sendFailed: return "Failed to send data"
        case .receiveFailed: return "Failed to receive data"
        case .pairVerifyFailed: return "Pair-verify failed"
        case .encryptionFailed: return "Encryption failed"
        case .decryptionFailed: return "Decryption failed"
        case .notEncrypted: return "Connection not encrypted"
        }
    }
}

public enum HIDCommand: Int {
    case up = 1
    case down = 2
    case left = 3
    case right = 4
    case select = 6
    case menu = 7
    case home = 8
    case playPause = 10
    case volumeUp = 11
    case volumeDown = 12
}

public final class CompanionConnection {
    private var connection: NWConnection?
    public static let defaultConnectTimeoutNanoseconds: UInt64 = 10_000_000_000
    public static let defaultReceiveTimeoutNanoseconds: UInt64 = 15_000_000_000

    private let connectTimeoutNanoseconds: UInt64
    private let receiveTimeoutNanoseconds: UInt64
    private let queue = DispatchQueue(label: "companion.connection")

    private var encryptKey: Data?
    private var decryptKey: Data?
    private var encryptCounter: UInt64 = 0
    private var decryptCounter: UInt64 = 0

    public var isEncrypted: Bool {
        encryptKey != nil && decryptKey != nil
    }

    public init(
        connectTimeoutNanoseconds: UInt64 = CompanionConnection.defaultConnectTimeoutNanoseconds,
        receiveTimeoutNanoseconds: UInt64 = CompanionConnection.defaultReceiveTimeoutNanoseconds
    ) {
        self.connectTimeoutNanoseconds = connectTimeoutNanoseconds
        self.receiveTimeoutNanoseconds = receiveTimeoutNanoseconds
    }

    public func connect(to endpoint: NWEndpoint, via interface: NWInterface? = nil) async throws {
        NSLog("[Companion] Connecting to %@ via %@", String(describing: endpoint), interface?.name ?? "any interface")

        // Scoping to the interface the service was discovered on keeps the
        // connection off VPN interfaces — with a VPN as the primary route an
        // unscoped Bonjour connection binds to it and never becomes ready.
        let parameters = NWParameters.tcp
        parameters.requiredInterface = interface

        let connection = NWConnection(to: endpoint, using: parameters)
        self.connection = connection

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var hasResumed = false
                    connection.stateUpdateHandler = { state in
                        NSLog("[Companion] Connection state: %@", String(describing: state))
                        guard !hasResumed else { return }
                        switch state {
                        case .ready:
                            hasResumed = true
                            continuation.resume()
                        case .failed(let error):
                            hasResumed = true
                            continuation.resume(throwing: error)
                        case .cancelled:
                            hasResumed = true
                            continuation.resume(throwing: CompanionConnectionError.connectionFailed)
                        default:
                            break
                        }
                    }
                    connection.start(queue: self.queue)
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: self.connectTimeoutNanoseconds)
                NSLog("[Companion] Connect timed out, closing the connection")
                connection.cancel()
                throw CompanionConnectionError.timeout
            }

            _ = try await group.next()
            group.cancelAll()
        }

        NSLog("[Companion] Connected successfully")
    }

    public func disconnect() {
        connection?.cancel()
        connection = nil
    }

    public func sendFrame(type: FrameType, payload: Data) async throws {
        guard let connection = connection else {
            throw CompanionConnectionError.disconnected
        }

        var frame = Data()
        frame.append(type.rawValue)
        let length = UInt32(payload.count)
        frame.append(UInt8((length >> 16) & 0xFF))
        frame.append(UInt8((length >> 8) & 0xFF))
        frame.append(UInt8(length & 0xFF))
        frame.append(payload)

        NSLog("[Companion] Sending frame type=%d length=%d", type.rawValue, payload.count)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: frame, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    public func receiveFrame() async throws -> (FrameType, Data) {
        guard let connection = connection else {
            throw CompanionConnectionError.disconnected
        }

        NSLog("[Companion] Waiting to receive frame header...")

        let header = try await receiveExact(connection: connection, length: 4)

        let frameTypeRaw = header[0]
        let length = (Int(header[1]) << 16) | (Int(header[2]) << 8) | Int(header[3])

        NSLog("[Companion] Receiving frame type=%d length=%d", frameTypeRaw, length)

        let payload: Data
        if length > 0 {
            payload = try await receiveExact(connection: connection, length: length)
        } else {
            payload = Data()
        }

        let frameType = FrameType(rawValue: frameTypeRaw) ?? .unknown
        return (frameType, payload)
    }

    public func exchange(type: FrameType, message: [String: Any]) async throws -> [String: Any] {
        let payload = try OPACKCodec.encode(message)
        try await sendFrame(type: type, payload: payload)

        let (responseType, responsePayload) = try await receiveFrame()
        NSLog("[Companion] Received response type=%d", responseType.rawValue)

        let decoded = try OPACKCodec.decode(responsePayload)
        guard let dict = decoded as? [String: Any] else {
            throw CompanionConnectionError.invalidFrame
        }
        return dict
    }

    /// A peer that opens the socket but never answers must not stall the caller
    /// forever, so every read is bounded — the body just like the header.
    ///
    /// The timeout has to cancel the connection, not merely throw. `NWConnection.receive`
    /// is wrapped in a continuation that task cancellation cannot reach; without closing
    /// the socket its completion never fires, the child task never finishes, and the task
    /// group waits on it forever — the timeout would be thrown and then swallowed.
    private func receiveExact(connection: NWConnection, length: Int) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    connection.receive(minimumIncompleteLength: length, maximumLength: length) { data, _, _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let data = data, data.count == length {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(throwing: CompanionConnectionError.receiveFailed)
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: self.receiveTimeoutNanoseconds)
                NSLog("[Companion] Read timed out after %llu ns, closing the connection", self.receiveTimeoutNanoseconds)
                connection.cancel()
                throw CompanionConnectionError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    public func pairVerify(credentials: PairingCredentials) async throws {
        NSLog("[Companion] Starting pair-verify...")

        let verifier = Verifier(credentials: credentials)

        var step1TLV = TLV8()
        step1TLV.set(.sequence, value: 0x01)
        step1TLV[.publicKey] = verifier.publicKey

        let step1Message: [String: Any] = ["_pd": step1TLV.encode()]
        let step1Payload = try OPACKCodec.encode(step1Message)
        try await sendFrame(type: .pairVerifyStart, payload: step1Payload)
        NSLog("[Companion] Sent PV step 1 (public key)")

        let (_, step2Payload) = try await receiveFrame()
        NSLog("[Companion] Received PV step 2 response")

        let step2Decoded = try OPACKCodec.decode(step2Payload)
        guard let step2Dict = step2Decoded as? [String: Any],
              let step2Data = step2Dict["_pd"] as? Data else {
            NSLog("[Companion] ERROR: Invalid step 2 response format")
            throw CompanionConnectionError.pairVerifyFailed
        }

        let step2TLV = TLV8.decode(step2Data)
        guard let serverPublicKey = step2TLV[.publicKey] else {
            NSLog("[Companion] ERROR: No server public key in step 2")
            throw CompanionConnectionError.pairVerifyFailed
        }
        NSLog("[Companion] Got server public key: %d bytes", serverPublicKey.count)

        let step3TLVData = try verifier.processStep2Response(step2Data)

        let step3Message: [String: Any] = ["_pd": step3TLVData]
        let step3Payload = try OPACKCodec.encode(step3Message)
        try await sendFrame(type: .pairVerifyNext, payload: step3Payload)
        NSLog("[Companion] Sent PV step 3 (encrypted signature)")

        let (_, step4Payload) = try await receiveFrame()
        NSLog("[Companion] Received PV step 4 response")

        let step4Decoded = try OPACKCodec.decode(step4Payload)
        if let step4Dict = step4Decoded as? [String: Any],
           let step4Data = step4Dict["_pd"] as? Data {
            let step4TLV = TLV8.decode(step4Data)
            if let errorCode = step4TLV[.errorCode] {
                NSLog("[Companion] ERROR: Pair-verify failed with error: %@", errorCode.hexString)
                throw CompanionConnectionError.pairVerifyFailed
            }
        }

        let sessionKeys = try verifier.deriveSessionKeys(serverPublicKey: serverPublicKey)
        self.encryptKey = sessionKeys.writeKey
        self.decryptKey = sessionKeys.readKey
        self.encryptCounter = 0
        self.decryptCounter = 0
        NSLog("[Companion] Pair-verify complete, encryption enabled")
    }

    public func sendEncryptedFrame(message: [String: Any]) async throws {
        guard let encryptKey = encryptKey else {
            throw CompanionConnectionError.notEncrypted
        }

        let plaintext = try OPACKCodec.encode(message)
        let ciphertext = try Encryption.chacha20Poly1305EncryptWithCounter(
            plaintext: plaintext,
            key: encryptKey,
            counter: encryptCounter
        )
        encryptCounter += 1

        try await sendFrame(type: .opackEncrypted, payload: ciphertext)
    }

    public func receiveEncryptedFrame() async throws -> [String: Any] {
        guard let decryptKey = decryptKey else {
            throw CompanionConnectionError.notEncrypted
        }

        let (frameType, ciphertext) = try await receiveFrame()

        guard frameType == .opackEncrypted else {
            NSLog("[Companion] Expected encrypted frame, got type=%d", frameType.rawValue)
            throw CompanionConnectionError.invalidFrame
        }

        let plaintext = try Encryption.chacha20Poly1305DecryptWithCounter(
            ciphertext: ciphertext,
            key: decryptKey,
            counter: decryptCounter
        )
        decryptCounter += 1

        let decoded = try OPACKCodec.decode(plaintext)
        guard let dict = decoded as? [String: Any] else {
            throw CompanionConnectionError.invalidFrame
        }
        return dict
    }

    public func sendHIDCommand(_ command: HIDCommand, buttonState: Int) async throws {
        let message: [String: Any] = [
            "_i": "_hidC",
            "_t": 1,
            "_c": [
                "_hBtS": buttonState,
                "_hidC": command.rawValue
            ]
        ]
        try await sendEncryptedFrame(message: message)
        NSLog("[Companion] Sent HID command %d state=%d", command.rawValue, buttonState)
    }

    public func pressButton(_ command: HIDCommand) async throws {
        try await sendHIDCommand(command, buttonState: 1)
        try await Task.sleep(nanoseconds: 50_000_000)
        try await sendHIDCommand(command, buttonState: 2)
    }
}
