import Foundation
import Network

public enum MockData {

    public static let livingRoomTV = AppleTVDevice(
        id: "mock-living-room",
        name: "Living Room",
        host: .ipv4(IPv4Address("192.168.1.42")!),
        port: .init(integerLiteral: 49152),
        model: "AppleTV6,2",
        isPaired: false,
        isConnected: false
    )

    public static let bedroomTV = AppleTVDevice(
        id: "mock-bedroom",
        name: "Bedroom",
        host: .ipv4(IPv4Address("192.168.1.43")!),
        port: .init(integerLiteral: 49152),
        model: "AppleTV11,1",
        isPaired: false,
        isConnected: false
    )

    public static var pairedTV: AppleTVDevice {
        return AppleTVDevice(
            id: "mock-paired",
            name: "Living Room",
            host: .ipv4(IPv4Address("192.168.1.42")!),
            port: .init(integerLiteral: 49152),
            model: "AppleTV6,2",
            isPaired: true,
            isConnected: false
        )
    }

    public static let mockCredentials = PairingCredentials(
        deviceId: livingRoomTV.id,
        ltpk: Data(repeating: 0x01, count: 32),
        ltsk: Data(repeating: 0x02, count: 32),
        peerPublicKey: Data(repeating: 0x03, count: 32),
        identifier: Data("mock-identifier".utf8),
        pairingId: "MOCK-PAIRING-ID"
    )

    public static var pairedCredentials: PairingCredentials {
        PairingCredentials(
            deviceId: "mock-paired",
            ltpk: Data(repeating: 0x01, count: 32),
            ltsk: Data(repeating: 0x02, count: 32),
            peerPublicKey: Data(repeating: 0x03, count: 32),
            identifier: Data("mock-paired-identifier".utf8),
            pairingId: "MOCK-PAIRED-ID"
        )
    }

    public static let playingInfo = PlaybackInfo(
        title: "Test Song",
        artist: "Test Artist",
        album: "Test Album",
        duration: 180,
        position: 45,
        state: .playing
    )

    public static let pausedInfo = PlaybackInfo(
        title: "Test Song",
        artist: "Test Artist",
        album: "Test Album",
        duration: 180,
        position: 45,
        state: .paused
    )

    public static let subscriptionExpiration = Date(timeIntervalSince1970: 1_800_000_000)

    public static let subscriptionOffers = [
        SubscriptionOffer(
            id: SubscriptionProductID.yearly,
            displayName: "Pro Yearly",
            description: "Full control of every Apple TV on your network.",
            displayPrice: "€19.99",
            period: .yearly,
            hasIntroductoryOffer: true
        ),
        SubscriptionOffer(
            id: SubscriptionProductID.monthly,
            displayName: "Pro Monthly",
            description: "Full control of every Apple TV on your network.",
            displayPrice: "€2.49",
            period: .monthly,
            hasIntroductoryOffer: false
        )
    ]
}
