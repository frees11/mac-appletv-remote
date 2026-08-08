import SwiftUI
import ATVRemoteCore

struct DemoModeBanner: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 12))

            Text("Demo — simulated Apple TVs, nothing on your network is touched.")
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("Exit") {
                appState.setDemoMode(false)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .accessibilityIdentifier(AccessibilityID.DemoBanner.exitButton)
        }
        .foregroundStyle(.black.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#f5c451"))
        .accessibilityIdentifier(AccessibilityID.DemoBanner.container)
    }
}
