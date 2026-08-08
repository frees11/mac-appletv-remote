import Foundation
import Combine

@MainActor
public protocol SubscriptionServiceProtocol: ObservableObject {
    var status: SubscriptionStatus { get }
    var offers: [SubscriptionOffer] { get }
    var isLoadingOffers: Bool { get }

    /// Lets `AppState` forward entitlement changes, so views observing it
    /// re-render when a purchase lands or a subscription lapses.
    var changePublisher: AnyPublisher<Void, Never> { get }

    /// Starts observing `Transaction.updates`. Must be called once at launch or
    /// purchases completed outside the app are never noticed.
    func start()

    func loadOffers() async throws
    func purchase(_ offerID: String) async throws -> SubscriptionPurchaseOutcome
    func restorePurchases() async throws
    func refreshStatus() async
}
