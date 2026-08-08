import Foundation

public enum SubscriptionProductID {
    public static let monthly = "com.atv.remote.pro.monthly"
    public static let yearly = "com.atv.remote.pro.yearly"

    public static let all = [monthly, yearly]
}

public struct SubscriptionOffer: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let displayPrice: String
    public let period: Period
    public let hasIntroductoryOffer: Bool

    public enum Period: String, Sendable {
        case monthly
        case yearly
        case other
    }

    public init(
        id: String,
        displayName: String,
        description: String,
        displayPrice: String,
        period: Period,
        hasIntroductoryOffer: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.period = period
        self.hasIntroductoryOffer = hasIntroductoryOffer
    }
}

public enum SubscriptionStatus: Equatable, Sendable {
    case unknown
    case notSubscribed
    case subscribed(productID: String, expirationDate: Date?)

    public var isActive: Bool {
        if case .subscribed = self { return true }
        return false
    }

    /// Views should not gate on a status that has not resolved yet, or the
    /// paywall flashes on every launch before the entitlement check finishes.
    public var isResolved: Bool {
        self != .unknown
    }
}

public enum SubscriptionPurchaseOutcome: Equatable, Sendable {
    case purchased
    case cancelled
    case pending
}

public enum SubscriptionError: LocalizedError, Equatable {
    case productsUnavailable
    case unverifiedTransaction
    case purchaseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            return "Subscription options could not be loaded from the App Store."
        case .unverifiedTransaction:
            return "The App Store returned a purchase that could not be verified."
        case .purchaseFailed(let reason):
            return "The purchase did not go through: \(reason)"
        }
    }
}
