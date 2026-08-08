import Foundation
import CryptoKit

public enum PairingConstants {
    public static let pairSetupControllerSignSalt = "Pair-Setup-Controller-Sign-Salt"
    public static let pairSetupControllerSignInfo = "Pair-Setup-Controller-Sign-Info"
    public static let pairSetupEncryptSalt = "Pair-Setup-Encrypt-Salt"
    public static let pairSetupEncryptInfo = "Pair-Setup-Encrypt-Info"

    public static let pairVerifyEncryptSalt = "Pair-Verify-Encrypt-Salt"
    public static let pairVerifyEncryptInfo = "Pair-Verify-Encrypt-Info"

    public static let mediaRemoteSalt = "MediaRemote-Salt"
    public static let mediaRemoteReadKey = "MediaRemote-Read-Encryption-Key"
    public static let mediaRemoteWriteKey = "MediaRemote-Write-Encryption-Key"
}

public struct Encryption {

    public static func hkdfSHA512(
        inputKeyMaterial: Data,
        salt: String,
        info: String,
        outputByteCount: Int = 32
    ) -> Data {
        let saltData = Data(salt.utf8)
        let infoData = Data(info.utf8)

        let symmetricKey = SymmetricKey(data: inputKeyMaterial)
        let derivedKey = HKDF<SHA512>.deriveKey(
            inputKeyMaterial: symmetricKey,
            salt: saltData,
            info: infoData,
            outputByteCount: outputByteCount
        )

        return derivedKey.withUnsafeBytes { Data($0) }
    }

    public static func hkdfSHA512(
        inputKeyMaterial: Data,
        salt: Data,
        info: Data,
        outputByteCount: Int = 32
    ) -> Data {
        let symmetricKey = SymmetricKey(data: inputKeyMaterial)
        let derivedKey = HKDF<SHA512>.deriveKey(
            inputKeyMaterial: symmetricKey,
            salt: salt,
            info: info,
            outputByteCount: outputByteCount
        )

        return derivedKey.withUnsafeBytes { Data($0) }
    }

    public static func chacha20Poly1305Encrypt(
        plaintext: Data,
        key: Data,
        nonce: Data
    ) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let chachaNonce = try ChaChaPoly.Nonce(data: nonce)
        let sealedBox = try ChaChaPoly.seal(plaintext, using: symmetricKey, nonce: chachaNonce)
        return sealedBox.ciphertext + sealedBox.tag
    }

    public static func chacha20Poly1305Decrypt(
        ciphertext: Data,
        key: Data,
        nonce: Data
    ) throws -> Data {
        guard ciphertext.count >= 16 else {
            throw EncryptionError.invalidCiphertext
        }

        let symmetricKey = SymmetricKey(data: key)
        let chachaNonce = try ChaChaPoly.Nonce(data: nonce)

        let encryptedData = ciphertext.prefix(ciphertext.count - 16)
        let tag = ciphertext.suffix(16)

        let sealedBox = try ChaChaPoly.SealedBox(
            nonce: chachaNonce,
            ciphertext: encryptedData,
            tag: tag
        )

        return try ChaChaPoly.open(sealedBox, using: symmetricKey)
    }

    public static func chacha20Poly1305EncryptWithCounter(
        plaintext: Data,
        key: Data,
        counter: UInt64
    ) throws -> Data {
        let nonce = makeNonce(from: counter)
        return try chacha20Poly1305Encrypt(plaintext: plaintext, key: key, nonce: nonce)
    }

    public static func chacha20Poly1305DecryptWithCounter(
        ciphertext: Data,
        key: Data,
        counter: UInt64
    ) throws -> Data {
        let nonce = makeNonce(from: counter)
        return try chacha20Poly1305Decrypt(ciphertext: ciphertext, key: key, nonce: nonce)
    }

    public static func makeNonce(from counter: UInt64) -> Data {
        var nonce = Data(count: 12)
        nonce[0] = 0
        nonce[1] = 0
        nonce[2] = 0
        nonce[3] = 0
        withUnsafeBytes(of: counter.littleEndian) { bytes in
            for i in 0..<8 {
                nonce[4 + i] = bytes[i]
            }
        }
        return nonce
    }

    public static func makeNonce(from string: String) -> Data {
        var nonce = Data(count: 12)
        let stringBytes = Data(string.utf8)
        let copyCount = min(stringBytes.count, 8)
        for i in 0..<copyCount {
            nonce[4 + i] = stringBytes[i]
        }
        return nonce
    }
}

public struct Ed25519Wrapper {
    public let privateKey: Curve25519.Signing.PrivateKey
    public let publicKey: Curve25519.Signing.PublicKey

    public var publicKeyData: Data {
        publicKey.rawRepresentation
    }

    public var privateKeyData: Data {
        privateKey.rawRepresentation
    }

    public init() {
        self.privateKey = Curve25519.Signing.PrivateKey()
        self.publicKey = privateKey.publicKey
    }

    public init(privateKeyData: Data) throws {
        self.privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
        self.publicKey = privateKey.publicKey
    }

    public func sign(_ data: Data) throws -> Data {
        try privateKey.signature(for: data)
    }

    public static func verify(signature: Data, message: Data, publicKey: Data) -> Bool {
        guard let pubKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey) else {
            return false
        }
        return pubKey.isValidSignature(signature, for: message)
    }
}

public struct Curve25519Wrapper {
    public let privateKey: Curve25519.KeyAgreement.PrivateKey
    public let publicKey: Curve25519.KeyAgreement.PublicKey

    public var publicKeyData: Data {
        publicKey.rawRepresentation
    }

    public var privateKeyData: Data {
        privateKey.rawRepresentation
    }

    public init() {
        self.privateKey = Curve25519.KeyAgreement.PrivateKey()
        self.publicKey = privateKey.publicKey
    }

    public init(privateKeyData: Data) throws {
        self.privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        self.publicKey = privateKey.publicKey
    }

    public func sharedSecret(with peerPublicKey: Data) throws -> Data {
        let peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerKey)
        return sharedSecret.withUnsafeBytes { Data($0) }
    }
}

public enum EncryptionError: Error, LocalizedError {
    case invalidCiphertext
    case invalidKey
    case invalidNonce
    case decryptionFailed
    case signatureFailed

    public var errorDescription: String? {
        switch self {
        case .invalidCiphertext:
            return "Invalid ciphertext: too short for tag"
        case .invalidKey:
            return "Invalid key data"
        case .invalidNonce:
            return "Invalid nonce data"
        case .decryptionFailed:
            return "Decryption failed"
        case .signatureFailed:
            return "Signature verification failed"
        }
    }
}

public extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
