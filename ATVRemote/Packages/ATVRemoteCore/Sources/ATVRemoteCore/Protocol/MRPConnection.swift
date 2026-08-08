import Foundation
import Network
import SwiftProtobuf

public enum MRPConnectionError: Error, LocalizedError {
    case notConnected
    case connectionFailed
    case sendFailed
    case receiveFailed
    case encryptionFailed
    case decryptionFailed
    case invalidMessage
    case verificationFailed

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Apple TV"
        case .connectionFailed:
            return "Failed to connect to Apple TV"
        case .sendFailed:
            return "Failed to send message"
        case .receiveFailed:
            return "Failed to receive message"
        case .encryptionFailed:
            return "Failed to encrypt message"
        case .decryptionFailed:
            return "Failed to decrypt message"
        case .invalidMessage:
            return "Invalid protocol message"
        case .verificationFailed:
            return "Verification failed"
        }
    }
}

@MainActor
public protocol MRPConnectionDelegate: AnyObject {
    func connectionDidConnect(_ connection: MRPConnection)
    func connectionDidDisconnect(_ connection: MRPConnection)
    func connection(_ connection: MRPConnection, didReceiveMessage message: ProtobufMessage)
    func connection(_ connection: MRPConnection, didReceiveError error: Error)
}

public final class MRPConnection: @unchecked Sendable {
    public weak var delegate: MRPConnectionDelegate?

    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let clientIdentifier: String
    private var connection: NWConnection?
    private var sessionKeys: SessionKeys?
    private var verifier: Verifier?

    private var encryptCounter: UInt64 = 0
    private var decryptCounter: UInt64 = 0

    private var receiveBuffer = Data()
    private let queue = DispatchQueue(label: "com.atvremote.mrpconnection")

    public var isConnected: Bool {
        connection?.state == .ready
    }

    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, clientIdentifier: String) {
        self.host = host
        self.port = port
        self.clientIdentifier = clientIdentifier
    }

    /// Connects and subscribes to now-playing updates. Passing `nil` credentials
    /// keeps the session unencrypted, which is what devices exposing direct MRP
    /// without system pairing expect.
    public func connect(credentials: PairingCredentials? = nil) async throws {
        NSLog("[MRP] Connecting to %@:%d", host.debugDescription, port.rawValue)

        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
                NSLog("[MRP] Connection state: %@", String(describing: state))
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: MRPConnectionError.connectionFailed)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }

        NSLog("[MRP] TCP connected, starting receive loop")
        startReceiving()

        NSLog("[MRP] Sending DeviceInfo...")
        try await sendDeviceInfo()

        if let credentials {
            NSLog("[MRP] Starting pair-verify...")
            let verifier = Verifier(credentials: credentials)
            self.verifier = verifier

            NSLog("[MRP] Sending pair-verify step 1 (public key)")
            let step1TLV = verifier.buildStep1TLV()
            try await sendPairingMessage(tlvData: step1TLV, state: 3)

            NSLog("[MRP] Waiting for pair-verify step 2 response...")
            let step2Response = try await waitForPairingResponse()
            NSLog("[MRP] Got step 2 response: %d bytes", step2Response.count)
            let step2TLV = TLV8.decode(step2Response)

            guard let serverPublicKey = step2TLV[.publicKey] else {
                NSLog("[MRP] ERROR: No server public key in step 2")
                throw MRPConnectionError.verificationFailed
            }
            NSLog("[MRP] Got server session public key: %d bytes", serverPublicKey.count)

            NSLog("[MRP] Processing step 2, building step 3...")
            let step3TLV = try verifier.processStep2Response(step2Response)
            NSLog("[MRP] Sending pair-verify step 3 (encrypted signature)")
            try await sendPairingMessage(tlvData: step3TLV, state: 3, isUsingSystemPairing: true)

            NSLog("[MRP] Waiting for pair-verify step 4 response...")
            _ = try await waitForPairingResponse()
            NSLog("[MRP] Got step 4 response - verification complete!")

            self.sessionKeys = try verifier.deriveSessionKeys(serverPublicKey: serverPublicKey)
            encryptCounter = 0
            decryptCounter = 0
            NSLog("[MRP] Session keys derived, encryption enabled")
        } else {
            NSLog("[MRP] No credentials supplied, staying on an unencrypted session")
        }

        NSLog("[MRP] Sending connection state...")
        try await sendConnectionState()

        NSLog("[MRP] Sending client updates config...")
        try await sendClientUpdatesConfig()

        NSLog("[MRP] Connection fully established!")
        await MainActor.run {
            delegate?.connectionDidConnect(self)
        }
    }

    public func disconnect() {
        connection?.cancel()
        connection = nil
        sessionKeys = nil
        encryptCounter = 0
        decryptCounter = 0
        receiveBuffer = Data()
    }

    public func sendCommand(_ command: RemoteCommand) async throws {
        let key = HIDEventBuilder.keyFromCommand(command)
        try await sendKeyPress(key: key)
    }

    public func sendKeyPress(key: HIDKey) async throws {
        let (press, release) = HIDEventBuilder.buildPressAndRelease(key: key)

        var pressMessage = SendHIDEventMessage()
        pressMessage.hidEventData = press
        try await sendProtobufMessage(pressMessage, type: .sendHidEventMessage)

        try await Task.sleep(nanoseconds: 50_000_000)

        var releaseMessage = SendHIDEventMessage()
        releaseMessage.hidEventData = release
        try await sendProtobufMessage(releaseMessage, type: .sendHidEventMessage)
    }

    public func sendKeyHold(key: HIDKey, duration: TimeInterval = 2.0) async throws {
        let press = HIDEventBuilder.buildEvent(key: key, pressed: true)
        let release = HIDEventBuilder.buildEvent(key: key, pressed: false)

        var pressMessage = SendHIDEventMessage()
        pressMessage.hidEventData = press
        try await sendProtobufMessage(pressMessage, type: .sendHidEventMessage)

        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        var releaseMessage = SendHIDEventMessage()
        releaseMessage.hidEventData = release
        try await sendProtobufMessage(releaseMessage, type: .sendHidEventMessage)
    }

    private func sendDeviceInfo() async throws {
        var deviceInfo = DeviceInfoMessage()
        deviceInfo.uniqueIdentifier = clientIdentifier
        deviceInfo.name = "ATV Remote Pro"
        deviceInfo.localizedModelName = "iPhone"
        deviceInfo.systemBuildVersion = "21A329"
        deviceInfo.protocolVersion = 1
        deviceInfo.allowsPairing = true
        deviceInfo.lastSupportedMessageType = 82
        deviceInfo.supportsSystemPairing = true

        try await sendProtobufMessage(deviceInfo, type: .deviceInfoMessage, waitForResponse: true)
    }

    private func sendPairingMessage(tlvData: Data, state: Int32, isUsingSystemPairing: Bool = false) async throws {
        var pairingMessage = CryptoPairingMessage()
        pairingMessage.pairingData = tlvData
        pairingMessage.status = 0
        pairingMessage.state = state
        pairingMessage.isRetrying = false
        pairingMessage.isUsingSystemPairing = isUsingSystemPairing

        try await sendProtobufMessage(pairingMessage, type: .cryptoPairingMessage, waitForResponse: false)
    }

    private func waitForPairingResponse() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let timeout = DispatchWorkItem { [weak self] in
                continuation.resume(throwing: MRPConnectionError.receiveFailed)
            }
            queue.asyncAfter(deadline: .now() + 5, execute: timeout)

            self.pairingResponseContinuation = { data in
                timeout.cancel()
                continuation.resume(returning: data)
            }
        }
    }

    private var pairingResponseContinuation: ((Data) -> Void)?

    private func sendConnectionState() async throws {
        var message = SetConnectionStateMessage()
        message.state = .connected

        try await sendProtobufMessage(message, type: .setConnectionStateMessage)
    }

    private func sendClientUpdatesConfig() async throws {
        var config = ClientUpdatesConfigMessage()
        config.nowPlayingUpdates = true
        config.artworkUpdates = true
        config.keyboardUpdates = false
        config.volumeUpdates = true

        try await sendProtobufMessage(config, type: .clientUpdatesConfigMessage)
    }

    private func sendProtobufMessage<T: SwiftProtobuf.Message>(
        _ message: T,
        type: ProtobufMessage.TypeEnum,
        waitForResponse: Bool = false
    ) async throws {
        var protocolMessage = ProtobufMessage()
        protocolMessage.type = type

        if waitForResponse {
            protocolMessage.identifier = UUID().uuidString
        }

        switch type {
        case .deviceInfoMessage:
            protocolMessage.deviceInfoMessage = message as! DeviceInfoMessage
        case .cryptoPairingMessage:
            protocolMessage.cryptoPairingMessage = message as! CryptoPairingMessage
        case .setConnectionStateMessage:
            protocolMessage.setConnectionStateMessage = message as! SetConnectionStateMessage
        case .clientUpdatesConfigMessage:
            protocolMessage.clientUpdatesConfigMessage = message as! ClientUpdatesConfigMessage
        case .sendHidEventMessage:
            protocolMessage.sendHideventMessage = message as! SendHIDEventMessage
        case .sendCommandMessage:
            protocolMessage.sendCommandMessage = message as! SendCommandMessage
        default:
            break
        }

        try await sendRawMessage(protocolMessage)
    }

    private func sendRawMessage(_ message: ProtobufMessage) async throws {
        guard let connection = connection, isConnected else {
            throw MRPConnectionError.notConnected
        }

        var messageData = try message.serializedData()

        if let keys = sessionKeys {
            messageData = try Encryption.chacha20Poly1305EncryptWithCounter(
                plaintext: messageData,
                key: keys.writeKey,
                counter: encryptCounter
            )
            encryptCounter += 1
        }

        let lengthData = encodeVarint(UInt64(messageData.count))
        let fullMessage = lengthData + messageData

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: fullMessage, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func startReceiving() {
        guard let connection = connection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.receiveBuffer.append(data)
                self.processBuffer()
            }

            if let error = error {
                Task { @MainActor in
                    self.delegate?.connection(self, didReceiveError: error)
                }
            } else if isComplete {
                Task { @MainActor in
                    self.delegate?.connectionDidDisconnect(self)
                }
            } else {
                self.startReceiving()
            }
        }
    }

    private func processBuffer() {
        while !receiveBuffer.isEmpty {
            guard let (length, bytesRead) = decodeVarint(from: receiveBuffer) else {
                break
            }

            let totalLength = bytesRead + Int(length)
            guard receiveBuffer.count >= totalLength else {
                break
            }

            // Index-relative slicing only: a Data that has been sliced keeps its
            // original indices, so absolute subscripts would run out of bounds.
            var messageData = Data(receiveBuffer.dropFirst(bytesRead).prefix(Int(length)))
            receiveBuffer = Data(receiveBuffer.dropFirst(totalLength))

            if let keys = sessionKeys {
                do {
                    messageData = try Encryption.chacha20Poly1305DecryptWithCounter(
                        ciphertext: messageData,
                        key: keys.readKey,
                        counter: decryptCounter
                    )
                    decryptCounter += 1
                } catch {
                    Task { @MainActor in
                        self.delegate?.connection(self, didReceiveError: MRPConnectionError.decryptionFailed)
                    }
                    continue
                }
            }

            do {
                let message = try ProtobufMessage(serializedData: messageData)
                handleMessage(message)
            } catch {
                Task { @MainActor in
                    self.delegate?.connection(self, didReceiveError: MRPConnectionError.invalidMessage)
                }
            }
        }
    }

    private func handleMessage(_ message: ProtobufMessage) {
        if message.type == .cryptoPairingMessage && message.hasCryptoPairingMessage {
            pairingResponseContinuation?(message.cryptoPairingMessage.pairingData)
            pairingResponseContinuation = nil
        } else {
            Task { @MainActor in
                self.delegate?.connection(self, didReceiveMessage: message)
            }
        }
    }

    private func encodeVarint(_ value: UInt64) -> Data {
        var result = Data()
        var v = value
        while v > 127 {
            result.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        result.append(UInt8(v))
        return result
    }

    private func decodeVarint(from data: Data) -> (value: UInt64, bytesRead: Int)? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var bytesRead = 0

        for byte in data {
            value |= UInt64(byte & 0x7F) << shift
            bytesRead += 1
            if byte & 0x80 == 0 {
                return (value, bytesRead)
            }
            shift += 7
            if shift > 63 {
                return nil
            }
        }
        return nil
    }
}
