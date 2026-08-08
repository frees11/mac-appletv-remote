import Foundation
import Combine
import StoreKit
import os

@MainActor
public final class SubscriptionService: SubscriptionServiceProtocol {
    @Published public private(set) var status: SubscriptionStatus = .unknown
    @Published public private(set) var offers: [SubscriptionOffer] = []
    @Published public private(set) var isLoadingOffers = false

    public var changePublisher: AnyPublisher<Void, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    private let changeSubject = PassthroughSubject<Void, Never>()
    private let logger = Logger(subsystem: "com.atv.remote", category: "Subscription")
    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    public init() {}

    deinit {
        updatesTask?.cancel()
    }

    public func start() {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.verified(update) else {
                    self.logger.error("Ignoring an unverified transaction from Transaction.updates")
                    continue
                }
                await transaction.finish()
                await self.refreshStatus()
            }
        }

        Task { await refreshStatus() }
    }

    public func loadOffers() async throws {
        isLoadingOffers = true
        changeSubject.send()
        defer {
            isLoadingOffers = false
            changeSubject.send()
        }

        do {
            let fetched = try await Product.products(for: SubscriptionProductID.all)
            guard !fetched.isEmpty else {
                logger.error("App Store returned no products for \(SubscriptionProductID.all.joined(separator: ", "))")
                throw SubscriptionError.productsUnavailable
            }

            products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            offers = fetched.map(Self.makeOffer).sorted { $0.period == .yearly && $1.period != .yearly }
        } catch let error as SubscriptionError {
            throw error
        } catch {
            logger.error("Loading products failed: \(error.localizedDescription, privacy: .public)")
            throw SubscriptionError.productsUnavailable
        }
    }

    public func purchase(_ offerID: String) async throws -> SubscriptionPurchaseOutcome {
        guard let product = products[offerID] else {
            logger.error("Purchase requested for a product that was never loaded: \(offerID, privacy: .public)")
            throw SubscriptionError.productsUnavailable
        }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        }

        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            await refreshStatus()
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            logger.error("App Store returned an unknown purchase result")
            throw SubscriptionError.purchaseFailed("unknown result")
        }
    }

    public func restorePurchases() async throws {
        do {
            try await AppStore.sync()
        } catch {
            logger.error("Restoring purchases failed: \(error.localizedDescription, privacy: .public)")
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        }
        await refreshStatus()
    }

    public func refreshStatus() async {
        var resolved: SubscriptionStatus = .notSubscribed

        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? verified(entitlement) else {
                logger.error("Ignoring an unverified entitlement")
                continue
            }
            guard SubscriptionProductID.all.contains(transaction.productID) else { continue }
            if let revocation = transaction.revocationDate, revocation <= Date() { continue }

            resolved = .subscribed(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate
            )
            break
        }

        guard resolved != status else { return }
        status = resolved
        changeSubject.send()
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            logger.error("StoreKit verification failed: \(error.localizedDescription, privacy: .public)")
            throw SubscriptionError.unverifiedTransaction
        }
    }

    private static func makeOffer(from product: Product) -> SubscriptionOffer {
        let period: SubscriptionOffer.Period
        switch product.subscription?.subscriptionPeriod.unit {
        case .month: period = .monthly
        case .year: period = .yearly
        default: period = .other
        }

        return SubscriptionOffer(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            period: period,
            hasIntroductoryOffer: product.subscription?.introductoryOffer != nil
        )
    }
}
