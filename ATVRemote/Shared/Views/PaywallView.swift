import SwiftUI
import ATVRemoteCore

struct PaywallView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedOfferID: String?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var hasAttemptedLoad = false

    private var offers: [SubscriptionOffer] { appState.subscriptionService.offers }
    private var isLoading: Bool { appState.subscriptionService.isLoadingOffers }

    var body: some View {
        VStack(spacing: 0) {
            header

            if offers.isEmpty && (isLoading || !hasAttemptedLoad) {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Spacer()
            } else if offers.isEmpty {
                Spacer()
                unavailableState
                Spacer()
            } else {
                offerList
                Spacer(minLength: 16)
                purchaseButton
            }

            footer
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#1c1c1e"))
        .accessibilityIdentifier(AccessibilityID.Paywall.view)
        .task { await loadOffers() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "appletv.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)

            Text("ATV Remote Pro")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)

            Text("Control every Apple TV on your network from your Mac.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 24)
        .padding(.bottom, 28)
    }

    private var offerList: some View {
        VStack(spacing: 12) {
            ForEach(offers) { offer in
                offerRow(offer)
            }
        }
    }

    private func offerRow(_ offer: SubscriptionOffer) -> some View {
        let isSelected = (selectedOfferID ?? offers.first?.id) == offer.id

        return Button {
            selectedOfferID = offer.id
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    if offer.hasIntroductoryOffer {
                        Text("2 months free, then \(offer.displayPrice)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text(offer.displayPrice)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .white.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Paywall.offer(offer.id))
    }

    private var purchaseButton: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Text(startButtonTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(isWorking || offers.isEmpty ? 0.4 : 1))
                )
            }
            .buttonStyle(.plain)
            .disabled(isWorking || offers.isEmpty)
            .accessibilityIdentifier(AccessibilityID.Paywall.subscribeButton)
        }
    }

    private var startButtonTitle: String {
        let offer = offers.first { $0.id == (selectedOfferID ?? offers.first?.id) }
        return offer?.hasIntroductoryOffer == true ? "Start 2-month free trial" : "Subscribe"
    }

    private var unavailableState: some View {
        VStack(spacing: 10) {
            Text("Subscription options could not be loaded.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await loadOffers() }
            }
            .buttonStyle(.bordered)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                Button("Restore purchases") {
                    Task { await restore() }
                }
                .accessibilityIdentifier(AccessibilityID.Paywall.restoreButton)

                Button("Try the demo") {
                    appState.setDemoMode(true)
                }
                .accessibilityIdentifier(AccessibilityID.Paywall.demoButton)
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.6))

            Text("Renews automatically. Cancel any time in System Settings.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 18)
    }

    private func loadOffers() async {
        errorMessage = nil
        defer { hasAttemptedLoad = true }
        do {
            try await appState.subscriptionService.loadOffers()
            selectedOfferID = appState.subscriptionService.offers.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func purchase() async {
        guard let offerID = selectedOfferID ?? offers.first?.id else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let outcome = try await appState.subscriptionService.purchase(offerID)
            if outcome == .pending {
                errorMessage = "The purchase is waiting for approval. It will unlock automatically once approved."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await appState.subscriptionService.restorePurchases()
            if !appState.subscriptionService.status.isActive {
                errorMessage = "No active subscription was found on this Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
