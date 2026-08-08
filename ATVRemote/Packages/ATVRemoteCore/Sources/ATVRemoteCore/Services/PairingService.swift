import Foundation
import Network
import CryptoKit

public enum PairingState: Equatable, Sendable {
    case idle
    case waitingForPin
    case processing
    case completed(PairingCredentials)
    case failed(String)
}

public enum PairingError: Error, LocalizedError {
    case connectionFailed
    case invalidResponse
    case backOffRequired(seconds: Int)
    case errorCode(Int)
    case saltLengthMismatch(Int)
    case publicKeyLengthMismatch(Int)
    case srpFailed(String)
    case serverProofInvalid
    case encryptionFailed
    case decryptionFailed
    case timeout
    case missingPairingData

    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to Apple TV"
        case .invalidResponse:
            return "Invalid response from Apple TV"
        case .backOffRequired(let seconds):
            return "Too many pairing attempts. Try again in \(seconds) seconds."
        case .errorCode(let code):
            return "Apple TV responded with error code \(code)"
        case .saltLengthMismatch(let length):
            return "Salt must be 16 bytes (got \(length))"
        case .publicKeyLengthMismatch(let length):
            return "Server public key must be 384 bytes (got \(length))"
        case .srpFailed(let reason):
            return "SRP computation failed: \(reason)"
        case .serverProofInvalid:
            return "Server proof M2 does not match"
        case .encryptionFailed:
            return "Failed to encrypt pairing data"
        case .decryptionFailed:
            return "Failed to decrypt server response"
        case .timeout:
            return "Pairing request timed out"
        case .missingPairingData:
            return "Missing pairing data in response"
        }
    }
}

@MainActor
public final class PairingService: ObservableObject, PairingServiceProtocol {
    public static let pinValiditySeconds = 37

    @Published public private(set) var state: PairingState = .idle

    private var device: AppleTVDevice?
    private var connection: CompanionConnection?
    private var srpClient: SRPClient?
    private var deviceSalt: Data?
    private var devicePublicKey: Data?
    private var pairingId: String
    private var encryptionSeed: Data?

    public init() {
        self.pairingId = UUID().uuidString.uppercased()
    }

    public func startPairing(device: AppleTVDevice) async throws -> @Sendable (String) async throws -> PairingCredentials {
        self.device = device
        self.state = .processing

        NSLog("[Pairing] Starting pairing with device: %@ at %@:%d", device.name, device.host.debugDescription, device.port.rawValue)

        let connection = CompanionConnection()
        try await connection.connect(host: device.host, port: device.port)
        self.connection = connection

        NSLog("[Pairing] Connected, sending PS_Start")

        var tlv = TLV8()
        tlv.set(.method, value: 0x00)
        tlv.set(.sequence, value: 0x01)

        let message: [String: Any] = [
            "_pd": tlv.encode(),
            "_pwTy": 1
        ]

        let response = try await connection.exchange(type: .pairSetupStart, message: message)

        guard let pairingData = response["_pd"] as? Data else {
            throw PairingError.missingPairingData
        }

        NSLog("[Pairing] Got PS_Start response: %d bytes pairing data", pairingData.count)

        let responseTLV = TLV8.decode(pairingData)

        if let backOff = responseTLV.backOff, backOff > 0 {
            state = .failed("Back off required")
            throw PairingError.backOffRequired(seconds: backOff)
        }

        if let errorCode = responseTLV.errorCode {
            state = .failed("Error code \(errorCode)")
            throw PairingError.errorCode(Int(errorCode))
        }

        guard let salt = responseTLV[.salt] else {
            NSLog("[Pairing] Missing salt in response")
            throw PairingError.invalidResponse
        }

        guard let serverPublicKey = responseTLV[.publicKey] else {
            NSLog("[Pairing] Missing public key in response")
            throw PairingError.invalidResponse
        }

        guard salt.count == 16 else {
            throw PairingError.saltLengthMismatch(salt.count)
        }

        guard serverPublicKey.count == 384 else {
            throw PairingError.publicKeyLengthMismatch(serverPublicKey.count)
        }

        NSLog("[Pairing] Got salt (%d bytes) and public key (%d bytes)", salt.count, serverPublicKey.count)

        self.deviceSalt = salt
        self.devicePublicKey = serverPublicKey
        self.state = .waitingForPin

        return { [weak self] pin in
            guard let self = self else {
                throw PairingError.connectionFailed
            }
            return try await self.completePairing(pin: pin)
        }
    }

    private func completePairing(pin: String) async throws -> PairingCredentials {
        guard let salt = deviceSalt,
              let serverPublicKey = devicePublicKey,
              let device = device,
              let connection = connection else {
            throw PairingError.invalidResponse
        }

        state = .processing

        NSLog("[Pairing] Completing pairing with PIN: %@", pin)

        let privateKey = generateRandomBytes(32)
        srpClient = SRPClient(
            salt: salt,
            identity: Data("Pair-Setup".utf8),
            password: Data(pin.utf8),
            privateKey: privateKey
        )

        guard let srp = srpClient else {
            throw PairingError.srpFailed("Failed to create SRP client")
        }

        try srp.setServerPublicKey(serverPublicKey)

        guard let clientPublicKey = srp.A as Data?,
              let proof = srp.M1 else {
            throw PairingError.srpFailed("Failed to compute client keys")
        }

        NSLog("[Pairing] SRP computed, sending PS_Next step 3")

        var step2TLV = TLV8()
        step2TLV.set(.sequence, value: 0x03)
        step2TLV[.publicKey] = clientPublicKey
        step2TLV[.proof] = proof

        let step2Message: [String: Any] = ["_pd": step2TLV.encode()]
        let step2Response = try await connection.exchange(type: .pairSetupNext, message: step2Message)

        guard let step2PairingData = step2Response["_pd"] as? Data else {
            throw PairingError.missingPairingData
        }

        let step2ResponseTLV = TLV8.decode(step2PairingData)

        if let errorCode = step2ResponseTLV.errorCode {
            state = .failed("Error code \(errorCode)")
            throw PairingError.errorCode(Int(errorCode))
        }

        guard let serverProof = step2ResponseTLV[.proof] else {
            NSLog("[Pairing] Missing server proof in step 2 response")
            throw PairingError.invalidResponse
        }

        NSLog("[Pairing] Got server proof, verifying")

        do {
            try srp.verifyServerProof(serverProof)
        } catch {
            throw PairingError.serverProofInvalid
        }

        guard let sharedSecret = srp.K else {
            throw PairingError.srpFailed("Failed to compute shared secret")
        }

        NSLog("[Pairing] Server proof verified, sending PS_Next step 5")

        let seed = generateRandomBytes(32)
        self.encryptionSeed = seed
        let signingKey = try Ed25519Wrapper(privateKeyData: seed)

        let deviceHash = Encryption.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: PairingConstants.pairSetupControllerSignSalt,
            info: PairingConstants.pairSetupControllerSignInfo,
            outputByteCount: 32
        )

        var deviceInfo = Data()
        deviceInfo.append(deviceHash)
        deviceInfo.append(Data(pairingId.utf8))
        deviceInfo.append(signingKey.publicKeyData)

        let signature = try signingKey.sign(deviceInfo)

        let encryptionKey = Encryption.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: PairingConstants.pairSetupEncryptSalt,
            info: PairingConstants.pairSetupEncryptInfo,
            outputByteCount: 32
        )

        var innerTLV = TLV8()
        innerTLV[.identifier] = Data(pairingId.utf8)
        innerTLV[.publicKey] = signingKey.publicKeyData
        innerTLV[.signature] = signature

        let innerTLVData = innerTLV.encode()

        let nonce = Encryption.makeNonce(from: "PS-Msg05")
        let encryptedData = try Encryption.chacha20Poly1305Encrypt(
            plaintext: innerTLVData,
            key: encryptionKey,
            nonce: nonce
        )

        var step3TLV = TLV8()
        step3TLV.set(.sequence, value: 0x05)
        step3TLV[.encryptedData] = encryptedData

        let step3Message: [String: Any] = ["_pd": step3TLV.encode()]
        let step3Response = try await connection.exchange(type: .pairSetupNext, message: step3Message)

        guard let step3PairingData = step3Response["_pd"] as? Data else {
            throw PairingError.missingPairingData
        }

        let step3ResponseTLV = TLV8.decode(step3PairingData)

        if let errorCode = step3ResponseTLV.errorCode {
            state = .failed("Error code \(errorCode)")
            throw PairingError.errorCode(Int(errorCode))
        }

        guard let encryptedResponseData = step3ResponseTLV[.encryptedData] else {
            NSLog("[Pairing] Missing encrypted data in step 3 response")
            throw PairingError.invalidResponse
        }

        let decryptNonce = Encryption.makeNonce(from: "PS-Msg06")
        let decryptedData = try Encryption.chacha20Poly1305Decrypt(
            ciphertext: encryptedResponseData,
            key: encryptionKey,
            nonce: decryptNonce
        )

        let responseInnerTLV = TLV8.decode(decryptedData)

        guard let tvIdentifier = responseInnerTLV[.identifier],
              let tvPublicKey = responseInnerTLV[.publicKey] else {
            NSLog("[Pairing] Missing identifier or public key in decrypted response")
            throw PairingError.invalidResponse
        }

        NSLog("[Pairing] Pairing complete! TV identifier: %d bytes", tvIdentifier.count)
        NSLog("[Pairing] TV identifier hex: %@", tvIdentifier.map { String(format: "%02x", $0) }.joined())
        NSLog("[Pairing] TV identifier as string: %@", String(data: tvIdentifier, encoding: .utf8) ?? "(not UTF-8)")

        let credentials = PairingCredentials(
            deviceId: device.id,
            ltpk: signingKey.publicKeyData,
            ltsk: seed,
            peerPublicKey: tvPublicKey,
            identifier: tvIdentifier,
            pairingId: pairingId
        )

        state = .completed(credentials)
        disconnect()

        return credentials
    }

    private func disconnect() {
        connection?.disconnect()
        connection = nil
    }

    private func generateRandomBytes(_ count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        return data
    }

    public func cancel() {
        disconnect()
        state = .idle
    }
}
