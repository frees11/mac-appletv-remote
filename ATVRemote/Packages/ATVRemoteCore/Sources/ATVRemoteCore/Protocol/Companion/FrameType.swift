import Foundation

public enum FrameType: UInt8 {
    case unknown = 0
    case noOp = 1
    case pairSetupStart = 3
    case pairSetupNext = 4
    case pairVerifyStart = 5
    case pairVerifyNext = 6
    case opackUnencrypted = 7
    case opackEncrypted = 8
    case familyIdentitySetup = 9
    case familyIdentityVerify = 10
}
