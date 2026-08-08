import Foundation
import CryptoKit

public struct SessionKeys: Sendable {
    public let readKey: Data
    public let writeKey: Data
}

public enum VerifyError: Error, LocalizedError {
    case invalidResponse
    case publicKeyLengthMismatch(Int)
    case identifierMismatch
    case signatureVerificationFailed
    case encryptionFailed
    case decryptionFailed
    case timeout

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Apple TV"
        case .publicKeyLengthMismatch(let length):
            return "Session public key must be 32 bytes (got \(length))"
        case .identifierMismatch:
            return "Device identifier does not match"
        case .signatureVerificationFailed:
            return "Signature verification failed"
        case .encryptionFailed:
            return "Failed to encrypt verify data"
        case .decryptionFailed:
            return "Failed to decrypt verify response"
        case .timeout:
            return "Verify request timed out"
        }
    }
}

public final class Verifier {
    private let credentials: PairingCredentials
    private let ephemeralKey: Curve25519Wrapper

    public init(credentials: PairingCredentials) {
        self.credentials = credentials
        self.ephemeralKey = Curve25519Wrapper()
    }

    public var publicKey: Data {
        ephemeralKey.publicKeyData
    }

    public func buildStep1TLV() -> Data {
        var tlv = TLV8()
        tlv.set(.sequence, value: 0x01)
        tlv[.publicKey] = ephemeralKey.publicKeyData
        return tlv.encode()
    }

    public func processStep2Response(_ responseData: Data) throws -> Data {
        NSLog("[Verifier] Processing step 2 response...")
        let tlv = TLV8.decode(responseData)

        guard let sessionPublicKey = tlv[.publicKey] else {
            NSLog("[Verifier] ERROR: No session public key")
            throw VerifyError.invalidResponse
        }

        guard sessionPublicKey.count == 32 else {
            NSLog("[Verifier] ERROR: Session public key wrong length: %d", sessionPublicKey.count)
            throw VerifyError.publicKeyLengthMismatch(sessionPublicKey.count)
        }

        guard let encryptedData = tlv[.encryptedData] else {
            NSLog("[Verifier] ERROR: No encrypted data")
            throw VerifyError.invalidResponse
        }
        NSLog("[Verifier] Got encrypted data: %d bytes", encryptedData.count)

        let sharedSecret = try ephemeralKey.sharedSecret(with: sessionPublicKey)
        NSLog("[Verifier] Computed shared secret")

        let encryptionKey = Encryption.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: PairingConstants.pairVerifyEncryptSalt,
            info: PairingConstants.pairVerifyEncryptInfo,
            outputByteCount: 32
        )
        NSLog("[Verifier] Derived encryption key")

        let nonce = Encryption.makeNonce(from: "PV-Msg02")
        NSLog("[Verifier] Decrypting with nonce: %@", nonce.map { String(format: "%02x", $0) }.joined(separator: " "))

        let decryptedData: Data
        do {
            decryptedData = try Encryption.chacha20Poly1305Decrypt(
                ciphertext: encryptedData,
                key: encryptionKey,
                nonce: nonce
            )
            NSLog("[Verifier] Decryption succeeded: %d bytes", decryptedData.count)
        } catch {
            NSLog("[Verifier] ERROR: Decryption failed: %@", error.localizedDescription)
            throw VerifyError.decryptionFailed
        }

        let innerTLV = TLV8.decode(decryptedData)

        guard let serverIdentifier = innerTLV[.identifier] else {
            throw VerifyError.invalidResponse
        }

        guard let signature = innerTLV[.signature] else {
            throw VerifyError.invalidResponse
        }

        NSLog("[Verifier] serverIdentifier (%d bytes): %@", serverIdentifier.count, serverIdentifier.map { String(format: "%02x", $0) }.joined())
        NSLog("[Verifier] credentials.identifier (%d bytes): %@", credentials.identifier.count, credentials.identifier.map { String(format: "%02x", $0) }.joined())

        if serverIdentifier != credentials.identifier {
            NSLog("[Verifier] WARNING: Identifier mismatch - got %d bytes, expected %d bytes", serverIdentifier.count, credentials.identifier.count)
            NSLog("[Verifier] serverIdentifier as string: %@", String(data: serverIdentifier, encoding: .utf8) ?? "(not UTF-8)")
            NSLog("[Verifier] credentials.identifier as string: %@", String(data: credentials.identifier, encoding: .utf8) ?? "(not UTF-8)")
            NSLog("[Verifier] Continuing with signature verification instead...")
        }

        var deviceInfo = Data()
        deviceInfo.append(sessionPublicKey)
        deviceInfo.append(serverIdentifier)
        deviceInfo.append(ephemeralKey.publicKeyData)

        guard Ed25519Wrapper.verify(
            signature: signature,
            message: deviceInfo,
            publicKey: credentials.peerPublicKey
        ) else {
            throw VerifyError.signatureVerificationFailed
        }

        var material = Data()
        material.append(ephemeralKey.publicKeyData)
        material.append(Data(credentials.pairingId.utf8))
        material.append(sessionPublicKey)

        let signingKey = try Ed25519Wrapper(privateKeyData: credentials.ltsk)
        let mySignature = try signingKey.sign(material)

        var plainTLV = TLV8()
        plainTLV[.identifier] = Data(credentials.pairingId.utf8)
        plainTLV[.signature] = mySignature

        let encryptNonce = Encryption.makeNonce(from: "PV-Msg03")
        let encryptedTLV = try Encryption.chacha20Poly1305Encrypt(
            plaintext: plainTLV.encode(),
            key: encryptionKey,
            nonce: encryptNonce
        )

        var outerTLV = TLV8()
        outerTLV.set(.sequence, value: 0x03)
        outerTLV[.encryptedData] = encryptedTLV

        return outerTLV.encode()
    }

    public func deriveSessionKeys(serverPublicKey: Data) throws -> SessionKeys {
        let sharedSecret = try ephemeralKey.sharedSecret(with: serverPublicKey)

        let readKey = Encryption.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: PairingConstants.mediaRemoteSalt,
            info: PairingConstants.mediaRemoteReadKey,
            outputByteCount: 32
        )

        let writeKey = Encryption.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: PairingConstants.mediaRemoteSalt,
            info: PairingConstants.mediaRemoteWriteKey,
            outputByteCount: 32
        )

        return SessionKeys(readKey: readKey, writeKey: writeKey)
    }
}
