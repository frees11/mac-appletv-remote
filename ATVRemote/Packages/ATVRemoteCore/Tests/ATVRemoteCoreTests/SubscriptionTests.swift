import XCTest
import Combine
@testable import ATVRemoteCore

@MainActor
final class SubscriptionTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testStatusGatesAccess() {
        XCTAssertFalse(SubscriptionStatus.notSubscribed.isActive)
        XCTAssertFalse(SubscriptionStatus.unknown.isActive)
        XCTAssertTrue(SubscriptionStatus.subscribed(productID: SubscriptionProductID.yearly, expirationDate: nil).isActive)
    }

    func testUnknownStatusIsNotResolved() {
        XCTAssertFalse(SubscriptionStatus.unknown.isResolved)
        XCTAssertTrue(SubscriptionStatus.notSubscribed.isResolved)
        XCTAssertTrue(SubscriptionStatus.subscribed(productID: SubscriptionProductID.monthly, expirationDate: nil).isResolved)
    }

    func testLoadingOffersNotifiesObservers() async throws {
        let service = MockSubscriptionService()
        var notifications = 0

        service.changePublisher
            .sink { notifications += 1 }
            .store(in: &cancellables)

        try await service.loadOffers()

        XCTAssertFalse(service.offers.isEmpty)
        XCTAssertGreaterThan(notifications, 0, "AppState re-renders off changePublisher, so a silent load leaves the paywall empty")
    }

    func testFailedOfferLoadStillNotifies() async {
        let service = MockSubscriptionService()
        service.shouldFailLoadingOffers = true
        var notifications = 0

        service.changePublisher
            .sink { notifications += 1 }
            .store(in: &cancellables)

        do {
            try await service.loadOffers()
            XCTFail("expected the load to throw")
        } catch {
            XCTAssertTrue(error is SubscriptionError)
        }

        XCTAssertTrue(service.offers.isEmpty)
        XCTAssertGreaterThan(notifications, 0)
        XCTAssertFalse(service.isLoadingOffers)
    }

    func testPurchaseActivatesSubscription() async throws {
        let service = MockSubscriptionService()
        XCTAssertFalse(service.status.isActive)

        let outcome = try await service.purchase(SubscriptionProductID.yearly)

        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(service.status.isActive)
    }

    func testCancelledPurchaseLeavesStatusUntouched() async throws {
        let service = MockSubscriptionService()
        service.purchaseOutcome = .cancelled

        let outcome = try await service.purchase(SubscriptionProductID.monthly)

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(service.status.isActive)
    }

    func testRestoreActivatesSubscription() async throws {
        let service = MockSubscriptionService()

        try await service.restorePurchases()

        XCTAssertTrue(service.status.isActive)
    }

    func testStatusChangeNotifiesObservers() {
        let service = MockSubscriptionService()
        var notifications = 0

        service.changePublisher
            .sink { notifications += 1 }
            .store(in: &cancellables)

        service.setStatus(.subscribed(productID: SubscriptionProductID.yearly, expirationDate: nil))
        service.setStatus(.subscribed(productID: SubscriptionProductID.yearly, expirationDate: nil))

        XCTAssertEqual(notifications, 1, "an unchanged status must not churn observers")
    }

    func testMockOffersCoverBothPeriods() {
        let periods = Set(MockData.subscriptionOffers.map(\.period))
        XCTAssertEqual(periods, [.yearly, .monthly])
        XCTAssertTrue(MockData.subscriptionOffers.contains { $0.hasIntroductoryOffer })
    }
}
