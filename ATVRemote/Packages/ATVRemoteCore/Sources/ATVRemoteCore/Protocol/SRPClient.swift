import Foundation
import BigInt
import CryptoKit

public struct SRPParameters {
    public let N: BigUInt
    public let g: BigUInt
    public let nLengthBits: Int

    public static let rfc3072: SRPParameters = {
        let nHex = """
            FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E08\
            8A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B\
            302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9\
            A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE6\
            49286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8\
            FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D\
            670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C\
            180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF695581718\
            3995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D\
            04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7D\
            B3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D226\
            1AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200C\
            BBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFC\
            E0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF
            """
        return SRPParameters(
            N: BigUInt(nHex, radix: 16)!,
            g: BigUInt(5),
            nLengthBits: 3072
        )
    }()

    public var nLengthBytes: Int {
        nLengthBits / 8
    }
}

public final class SRPClient {
    private let params: SRPParameters
    private let identity: Data
    private let password: Data
    private let salt: Data
    private let privateKey: BigUInt
    private let k: BigUInt
    private let x: BigUInt
    private let publicKeyA: BigUInt

    private var serverPublicKeyB: BigUInt?
    private var u: BigUInt?
    private var sessionKey: Data?
    private var m1: Data?
    private var m2: Data?

    public var A: Data {
        padToN(publicKeyA)
    }

    public var K: Data? {
        sessionKey
    }

    public var M1: Data? {
        m1
    }

    public init(
        params: SRPParameters = .rfc3072,
        salt: Data,
        identity: Data,
        password: Data,
        privateKey: Data? = nil
    ) {
        self.params = params
        self.salt = salt
        self.identity = identity
        self.password = password

        let secretKey = privateKey ?? Self.generateRandomKey(bytes: 32)
        self.privateKey = BigUInt(Data(secretKey))

        self.k = Self.computeK(params: params)
        self.x = Self.computeX(params: params, salt: salt, identity: identity, password: password)
        self.publicKeyA = Self.computeA(params: params, privateKey: self.privateKey)
    }

    public func setServerPublicKey(_ B: Data) throws {
        let B_num = BigUInt(B)

        guard B_num > 0, B_num < params.N else {
            throw SRPError.invalidServerPublicKey
        }

        self.serverPublicKeyB = B_num

        let A_buf = padToN(publicKeyA)
        let B_buf = padToN(B_num)
        self.u = Self.computeU(params: params, A: A_buf, B: B_buf)

        guard let u = self.u, u > 0 else {
            throw SRPError.invalidScrambler
        }

        let S = Self.computeClientS(
            params: params,
            k: k,
            x: x,
            a: privateKey,
            B: B_num,
            u: u
        )

        self.sessionKey = Self.computeK(S: padToN(S))

        guard let K = sessionKey else {
            throw SRPError.computationFailed
        }

        self.m1 = Self.computeM1(
            params: params,
            identity: identity,
            salt: salt,
            A: A_buf,
            B: B_buf,
            K: K
        )

        self.m2 = Self.computeM2(A: A_buf, M1: m1!, K: K)
    }

    public func verifyServerProof(_ serverM2: Data) throws {
        guard let expectedM2 = m2 else {
            throw SRPError.incompleteProtocol
        }

        guard serverM2 == expectedM2 else {
            throw SRPError.serverProofMismatch
        }
    }

    private static func generateRandomKey(bytes: Int) -> Data {
        var data = Data(count: bytes)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!) }
        return data
    }

    private static func sha512(_ data: Data) -> Data {
        Data(SHA512.hash(data: data))
    }

    private static func sha512(_ parts: Data...) -> Data {
        var hasher = SHA512()
        for part in parts {
            hasher.update(data: part)
        }
        return Data(hasher.finalize())
    }

    private static func computeK(params: SRPParameters) -> BigUInt {
        let N_buf = padTo(params.N.serialize(), length: params.nLengthBytes)
        let g_buf = padTo(params.g.serialize(), length: params.nLengthBytes)
        let hash = sha512(N_buf, g_buf)
        return BigUInt(hash)
    }

    private static func computeX(
        params: SRPParameters,
        salt: Data,
        identity: Data,
        password: Data
    ) -> BigUInt {
        var colonData = Data([0x3A])
        let innerHash = sha512(identity, colonData, password)
        let outerHash = sha512(salt, innerHash)
        return BigUInt(outerHash)
    }

    private static func computeA(params: SRPParameters, privateKey: BigUInt) -> BigUInt {
        params.g.power(privateKey, modulus: params.N)
    }

    private static func computeU(params: SRPParameters, A: Data, B: Data) -> BigUInt {
        let hash = sha512(A, B)
        return BigUInt(hash)
    }

    private static func computeClientS(
        params: SRPParameters,
        k: BigUInt,
        x: BigUInt,
        a: BigUInt,
        B: BigUInt,
        u: BigUInt
    ) -> BigUInt {
        let N = params.N
        let g = params.g

        let gx = g.power(x, modulus: N)
        let kgx = (k * gx) % N

        var base: BigUInt
        if B >= kgx {
            base = (B - kgx) % N
        } else {
            base = (B + N - kgx) % N
        }

        let exp = (a + u * x) % (N - 1)
        return base.power(exp, modulus: N)
    }

    private static func computeK(S: Data) -> Data {
        sha512(S)
    }

    private static func computeM1(
        params: SRPParameters,
        identity: Data,
        salt: Data,
        A: Data,
        B: Data,
        K: Data
    ) -> Data {
        let N_buf = params.N.serialize()
        let g_buf = params.g.serialize()

        var hN = Data(SHA512.hash(data: N_buf))
        let hG = Data(SHA512.hash(data: g_buf))

        for i in 0..<hN.count {
            hN[i] ^= hG[i]
        }

        let hI = sha512(identity)

        return sha512(hN, hI, salt, A, B, K)
    }

    private static func computeM2(A: Data, M1: Data, K: Data) -> Data {
        sha512(A, M1, K)
    }

    private func padToN(_ num: BigUInt) -> Data {
        Self.padTo(num.serialize(), length: params.nLengthBytes)
    }

    private static func padTo(_ data: Data, length: Int) -> Data {
        if data.count >= length {
            return data
        }
        var padded = Data(repeating: 0, count: length - data.count)
        padded.append(data)
        return padded
    }
}

public enum SRPError: Error, LocalizedError {
    case invalidServerPublicKey
    case invalidScrambler
    case computationFailed
    case incompleteProtocol
    case serverProofMismatch

    public var errorDescription: String? {
        switch self {
        case .invalidServerPublicKey:
            return "Invalid server public key B"
        case .invalidScrambler:
            return "Invalid scrambler u (zero)"
        case .computationFailed:
            return "SRP computation failed"
        case .incompleteProtocol:
            return "Protocol incomplete - setServerPublicKey not called"
        case .serverProofMismatch:
            return "Server proof M2 does not match"
        }
    }
}
