import Foundation
import Combine

@MainActor
public final class MockSubscriptionService: SubscriptionServiceProtocol {
    @Published public private(set) var status: SubscriptionStatus
    @Published public private(set) var offers: [SubscriptionOffer] = []
    @Published public private(set) var isLoadingOffers = false

    public var changePublisher: AnyPublisher<Void, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    public var shouldFailLoadingOffers = false
    public var shouldFailPurchase = false
    public var purchaseOutcome: SubscriptionPurchaseOutcome = .purchased
    public var loadDelay: TimeInterval = 0

    private let changeSubject = PassthroughSubject<Void, Never>()

    public init(status: SubscriptionStatus = .notSubscribed) {
        self.status = status
    }

    public func start() {}

    public func loadOffers() async throws {
        isLoadingOffers = true
        changeSubject.send()
        defer {
            isLoadingOffers = false
            changeSubject.send()
        }

        if loadDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(loadDelay * 1_000_000_000))
        }
        if shouldFailLoadingOffers {
            throw SubscriptionError.productsUnavailable
        }
        offers = MockData.subscriptionOffers
    }

    public func purchase(_ offerID: String) async throws -> SubscriptionPurchaseOutcome {
        if shouldFailPurchase {
            throw SubscriptionError.purchaseFailed("mock failure")
        }
        if purchaseOutcome == .purchased {
            setStatus(.subscribed(productID: offerID, expirationDate: MockData.subscriptionExpiration))
        }
        return purchaseOutcome
    }

    public func restorePurchases() async throws {
        if shouldFailPurchase {
            throw SubscriptionError.purchaseFailed("mock failure")
        }
        setStatus(.subscribed(productID: SubscriptionProductID.yearly, expirationDate: MockData.subscriptionExpiration))
    }

    public func refreshStatus() async {}

    public func setStatus(_ newStatus: SubscriptionStatus) {
        guard newStatus != status else { return }
        status = newStatus
        changeSubject.send()
    }
}
