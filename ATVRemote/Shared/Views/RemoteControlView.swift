import SwiftUI
import ATVRemoteCore

struct RemoteControlView: View {
    @EnvironmentObject var appState: AppState
    let device: AppleTVDevice

    private let longPressDuration: Double = 0.6
    private let volumeRepeatInterval: Double = 0.1

    private var isConnected: Bool {
        appState.connectionService.state == .connected
    }

    private var playbackInfo: PlaybackInfo? {
        appState.connectionService.playbackInfo
    }

    var body: some View {
        ZStack {
            remoteGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                if let info = playbackInfo, info.hasContent {
                    nowPlayingSection(info)
                }
                controlsSection
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .accessibilityIdentifier(AccessibilityID.Remote.view)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { sendCommand(.up); return .handled }
        .onKeyPress(.downArrow) { sendCommand(.down); return .handled }
        .onKeyPress(.leftArrow) { sendCommand(.left); return .handled }
        .onKeyPress(.rightArrow) { sendCommand(.right); return .handled }
        .onKeyPress(.return) { sendCommand(.select); return .handled }
        .onKeyPress(.space) { sendCommand(.select); return .handled }
        .onKeyPress(.escape) { sendCommand(.menu); return .handled }
    }

    private var remoteGradient: some View {
        LinearGradient(
            colors: [Color(hex: "#e6e6e6"), Color(hex: "#d0d0d0")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    appState.disconnectFromDevice()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#1d1d1f"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.Remote.backButton)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                        .accessibilityIdentifier(AccessibilityID.Remote.connectionIndicator)
                    Text(connectionStateText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#8e8e93"))
                }
            }

            VStack(spacing: 4) {
                Text(device.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "#1d1d1f"))
                    .accessibilityIdentifier(AccessibilityID.Remote.deviceName)

                if let ipAddress = device.ipAddress {
                    Text(ipAddress)
                        .font(.system(size: 12).monospaced())
                        .foregroundColor(Color(hex: "#8e8e93"))
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .padding(.bottom, 16)
    }

    private var connectionStateText: String {
        switch appState.connectionService.state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .verifying: return "Verifying..."
        case .connected: return "Connected"
        case .failed(let error): return "Failed: \(error)"
        }
    }

    private func nowPlayingSection(_ info: PlaybackInfo) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let title = info.title {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#1d1d1f"))
                        .lineLimit(1)
                        .accessibilityIdentifier(AccessibilityID.NowPlaying.trackTitle)
                }
                if let artist = info.artist {
                    Text(artist)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#8e8e93"))
                        .lineLimit(1)
                        .accessibilityIdentifier(AccessibilityID.NowPlaying.trackArtist)
                }
                if let album = info.album {
                    Text(album)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#aeaeb2"))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: info.isPlaying ? "play.fill" : "pause.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#1d1d1f"))
        }
        .padding(16)
        .background(Color.white.opacity(0.75))
        .cornerRadius(16)
        .padding(.bottom, 16)
        .accessibilityIdentifier(AccessibilityID.NowPlaying.section)
    }

    private var controlsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                PowerButton(onCommand: sendCommand)
            }
            .padding(.bottom, -8)

            TouchpadView(onCommand: sendCommand, longPressDuration: longPressDuration)
                .padding(.vertical, 16)

            HStack(spacing: 16) {
                LongPressButton(
                    icon: "chevron.left",
                    shortPressCommand: .menu,
                    longPressCommand: .home,
                    longPressDuration: longPressDuration,
                    onCommand: sendCommand,
                    accessibilityId: AccessibilityID.Remote.menuButton
                )

                LongPressButton(
                    icon: "tv",
                    shortPressCommand: .tv,
                    longPressCommand: .controlCenter,
                    longPressDuration: longPressDuration,
                    onCommand: sendCommand,
                    accessibilityId: AccessibilityID.Remote.tvButton
                )
            }

            HStack(spacing: 16) {
                LongPressButton(
                    icon: "playpause.fill",
                    shortPressCommand: .playPause,
                    longPressCommand: .stop,
                    longPressDuration: longPressDuration,
                    onCommand: sendCommand,
                    accessibilityId: AccessibilityID.Remote.playPauseButton
                )

                VolumeButton(
                    isUp: true,
                    repeatInterval: volumeRepeatInterval,
                    onCommand: sendCommand,
                    accessibilityId: AccessibilityID.Remote.volumeUpButton
                )
            }

            HStack(spacing: 16) {
                RemoteButton(icon: "speaker.slash", accessibilityId: AccessibilityID.Remote.muteButton) {
                    sendCommand(.mute)
                }

                VolumeButton(
                    isUp: false,
                    repeatInterval: volumeRepeatInterval,
                    onCommand: sendCommand,
                    accessibilityId: AccessibilityID.Remote.volumeDownButton
                )
            }
            .padding(.top, -8)
        }
    }

    private func sendCommand(_ command: RemoteCommand) {
        Task {
            do {
                try await appState.connectionService.sendCommand(command)
            } catch {
                print("Command error: \(error)")
            }
        }
    }
}

struct TouchpadView: View {
    let onCommand: (RemoteCommand) -> Void
    let longPressDuration: Double
    var accessibilityId: String = AccessibilityID.Remote.touchpad

    @State private var pressedDirection: TouchpadDirection?
    @State private var pressStart: Date?
    @State private var pressPosition: CGPoint?

    enum TouchpadDirection {
        case center, up, down, left, right
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#3a3a3c"), Color(hex: "#1c1c1e")],
                            center: lightCenter,
                            startRadius: 0,
                            endRadius: geometry.size.width / 2
                        )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 4, x: liftShadow.width, y: 2 + liftShadow.height)
                    .shadow(color: .black.opacity(0.2), radius: pressedDirection == nil ? 12 : 16, x: liftShadow.width * 2, y: 4 + liftShadow.height * 2)

                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .scaleEffect(0.5)

                pressShading
                    .clipShape(Circle())

                arrowIndicators
            }
            .scaleEffect(pressedDirection == .center ? 0.96 : 1.0)
            .animation(
                pressedDirection == nil
                    ? .easeOut(duration: 0.16)
                    : .easeOut(duration: 0.08),
                value: pressedDirection
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handlePress(at: value.location, in: geometry.size)
                    }
                    .onEnded { value in
                        handleRelease(at: value.location, in: geometry.size)
                    }
            )
        }
        .frame(width: 240, height: 240)
        .accessibilityIdentifier(accessibilityId)
    }

    private var arrowIndicators: some View {
        ZStack {
            chevron("chevron.up", for: .up, offset: CGSize(width: 0, height: -100))
            chevron("chevron.down", for: .down, offset: CGSize(width: 0, height: 100))
            chevron("chevron.left", for: .left, offset: CGSize(width: -100, height: 0))
            chevron("chevron.right", for: .right, offset: CGSize(width: 100, height: 0))
        }
    }

    private func chevron(_ icon: String, for direction: TouchpadDirection, offset: CGSize) -> some View {
        let isDirectionPressed = pressedDirection == direction
        // Rides the dent, otherwise the arrow floats above the sunken rim.
        let inwardShift: CGFloat = isDirectionPressed ? 0.96 : 1.0

        return Image(systemName: icon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white.opacity(isDirectionPressed ? 0.5 : 1.0))
            .offset(x: offset.width * inwardShift, y: offset.height * inwardShift)
    }

    /// The side going down falls into shadow, the side coming up catches a
    /// little light — that is what makes the tilt read as a press.
    @ViewBuilder
    private var pressShading: some View {
        if let direction = pressedDirection {
            if direction == .center {
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .scaleEffect(0.48)
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.65), Color.clear],
                            startPoint: sideStart(for: direction),
                            endPoint: .center
                        )
                    )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.clear],
                            startPoint: liftedSide(for: direction),
                            endPoint: .center
                        )
                    )
            }
        }
    }

    private func liftedSide(for direction: TouchpadDirection) -> UnitPoint {
        switch direction {
        case .up: return .bottom
        case .down: return .top
        case .left: return .trailing
        case .right: return .leading
        case .center: return .center
        }
    }

    /// The disc tips on its axis: the pressed side goes down in Z, the opposite
    /// side comes up. The silhouette stays a perfect circle, so the depth is
    /// carried entirely by light — the sunken side falls into shadow, the raised
    /// side catches the light and throws a longer shadow.
    private var liftShadow: CGSize {
        guard let direction = pressedDirection, direction != .center else { return .zero }

        let lift: CGFloat = 3
        switch direction {
        case .up: return CGSize(width: 0, height: lift)
        case .down: return CGSize(width: 0, height: -lift)
        case .left: return CGSize(width: lift, height: 0)
        case .right: return CGSize(width: -lift, height: 0)
        case .center: return .zero
        }
    }

    /// The tilt is done with light, not geometry: the disc stays a perfect
    /// circle and the lighting moves toward the side that lifted. Rotating the
    /// shape itself reads as the wheel spinning.
    private var lightCenter: UnitPoint {
        guard let direction = pressedDirection, direction != .center else {
            return .center
        }

        let shift: CGFloat = 0.34
        switch direction {
        case .up: return UnitPoint(x: 0.5, y: 0.5 + shift)
        case .down: return UnitPoint(x: 0.5, y: 0.5 - shift)
        case .left: return UnitPoint(x: 0.5 + shift, y: 0.5)
        case .right: return UnitPoint(x: 0.5 - shift, y: 0.5)
        case .center: return .center
        }
    }

    private func sideStart(for direction: TouchpadDirection) -> UnitPoint {
        switch direction {
        case .up: return .top
        case .down: return .bottom
        case .left: return .leading
        case .right: return .trailing
        case .center: return .center
        }
    }

    private func calculateDirection(at point: CGPoint, in size: CGSize) -> TouchpadDirection {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let radius = min(size.width, size.height) / 2

        if distance < radius * 0.5 {
            return .center
        }

        if abs(dx) > abs(dy) {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }

    private func handlePress(at point: CGPoint, in size: CGSize) {
        if pressStart == nil {
            pressStart = Date()
            pressPosition = point
        }
        pressedDirection = calculateDirection(at: point, in: size)
    }

    private func handleRelease(at point: CGPoint, in size: CGSize) {
        guard let start = pressStart else {
            pressedDirection = nil
            return
        }

        let duration = Date().timeIntervalSince(start)
        let isLongPress = duration >= longPressDuration
        let direction = calculateDirection(at: pressPosition ?? point, in: size)

        if isLongPress {
            switch direction {
            case .center: onCommand(.longSelect)
            case .up: onCommand(.longUp)
            case .down: onCommand(.longDown)
            case .left: onCommand(.longLeft)
            case .right: onCommand(.longRight)
            }
        } else {
            switch direction {
            case .center: onCommand(.select)
            case .up: onCommand(.up)
            case .down: onCommand(.down)
            case .left: onCommand(.left)
            case .right: onCommand(.right)
            }
        }

        pressStart = nil
        pressPosition = nil
        releaseAfterMinimumVisibleTime(pressedSince: start)
    }

    /// A tap can be shorter than the press-in animation, which would leave the
    /// depression invisible. Hold the pressed look until it has been on screen
    /// long enough to register; the command itself was already sent.
    private func releaseAfterMinimumVisibleTime(pressedSince start: Date) {
        let minimumVisible: TimeInterval = 0.12
        let shown = Date().timeIntervalSince(start)

        guard shown < minimumVisible else {
            pressedDirection = nil
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(minimumVisible - shown))
            if pressStart == nil {
                pressedDirection = nil
            }
        }
    }
}

struct RemoteButton: View {
    let icon: String
    let action: () -> Void
    var accessibilityId: String?

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#3a3a3c"), Color(hex: "#1c1c1e")],
                            center: .center,
                            startRadius: 0,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 3)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "#f5f5f7"))
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(accessibilityId ?? "")
    }
}

struct LongPressButton: View {
    let icon: String
    let shortPressCommand: RemoteCommand
    let longPressCommand: RemoteCommand
    let longPressDuration: Double
    let onCommand: (RemoteCommand) -> Void
    var accessibilityId: String?

    @State private var pressProgress: Double = 0
    @State private var pressStart: Date?
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#3a3a3c"), Color(hex: "#1c1c1e")],
                        center: .center,
                        startRadius: 0,
                        endRadius: 35
                    )
                )
                .frame(width: 70, height: 70)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 3)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)

            if pressProgress > 0 {
                Circle()
                    .trim(from: 0, to: pressProgress)
                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .white.opacity(0.6), radius: 4)
            }

            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(hex: "#f5f5f7"))
        }
        .accessibilityIdentifier(accessibilityId ?? "")
        .scaleEffect(pressStart != nil ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.1), value: pressStart != nil)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if pressStart == nil {
                        startPress()
                    }
                }
                .onEnded { _ in
                    endPress()
                }
        )
    }

    private func startPress() {
        pressStart = Date()
        pressProgress = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard let start = pressStart else { return }
            let elapsed = Date().timeIntervalSince(start)
            pressProgress = min(1.0, elapsed / longPressDuration)
        }
    }

    private func endPress() {
        timer?.invalidate()
        timer = nil

        guard let start = pressStart else { return }
        let duration = Date().timeIntervalSince(start)

        if duration >= longPressDuration {
            onCommand(longPressCommand)
        } else {
            onCommand(shortPressCommand)
        }

        pressStart = nil
        pressProgress = 0
    }
}

struct PowerButton: View {
    let onCommand: (RemoteCommand) -> Void
    var accessibilityId: String = AccessibilityID.Remote.powerButton

    @State private var pressProgress: Double = 0
    @State private var pressStart: Date?
    @State private var timer: Timer?

    private let longPressDuration: Double = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            if pressProgress > 0 {
                Circle()
                    .trim(from: 0, to: pressProgress)
                    .stroke(Color(hex: "#1d1d1f").opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color(hex: "#1d1d1f").opacity(0.4), radius: 4)
            }

            Image(systemName: "power")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#1d1d1f"))
        }
        .accessibilityIdentifier(accessibilityId)
        .scaleEffect(pressStart != nil ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.1), value: pressStart != nil)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if pressStart == nil {
                        startPress()
                    }
                }
                .onEnded { _ in
                    endPress()
                }
        )
    }

    private func startPress() {
        pressStart = Date()
        pressProgress = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard let start = pressStart else { return }
            let elapsed = Date().timeIntervalSince(start)
            pressProgress = min(1.0, elapsed / longPressDuration)
        }
    }

    private func endPress() {
        timer?.invalidate()
        timer = nil

        guard let start = pressStart else { return }
        let duration = Date().timeIntervalSince(start)

        if duration >= longPressDuration {
            onCommand(.powerOff)
        } else {
            onCommand(.power)
        }

        pressStart = nil
        pressProgress = 0
    }
}

struct VolumeButton: View {
    let isUp: Bool
    let repeatInterval: Double
    let onCommand: (RemoteCommand) -> Void
    var accessibilityId: String?

    @State private var isPressed = false
    @State private var repeatTimer: Timer?

    var body: some View {
        ZStack {
            VolumeButtonShape(isUp: isUp)
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#3a3a3c"), Color(hex: "#1c1c1e")],
                        center: .center,
                        startRadius: 0,
                        endRadius: 35
                    )
                )
                .frame(width: 70, height: 70)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 3)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)

            Text(isUp ? "+" : "−")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(Color(hex: "#f5f5f7"))
        }
        .accessibilityIdentifier(accessibilityId ?? "")
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        startPress()
                    }
                }
                .onEnded { _ in
                    endPress()
                }
        )
    }

    private func startPress() {
        isPressed = true
        let command: RemoteCommand = isUp ? .volumeUp : .volumeDown
        onCommand(command)

        repeatTimer = Timer.scheduledTimer(withTimeInterval: repeatInterval, repeats: true) { _ in
            onCommand(command)
        }
    }

    private func endPress() {
        isPressed = false
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

struct VolumeButtonShape: Shape {
    let isUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 35
        let smallRadius: CGFloat = 8

        if isUp {
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
            path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - smallRadius))
            path.addArc(center: CGPoint(x: rect.width - smallRadius, y: rect.height - smallRadius),
                       radius: smallRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: smallRadius, y: rect.height))
            path.addArc(center: CGPoint(x: smallRadius, y: rect.height - smallRadius),
                       radius: smallRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            path.move(to: CGPoint(x: smallRadius, y: 0))
            path.addLine(to: CGPoint(x: rect.width - smallRadius, y: 0))
            path.addArc(center: CGPoint(x: rect.width - smallRadius, y: smallRadius),
                       radius: smallRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))
            path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: rect.height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))
            path.addArc(center: CGPoint(x: cornerRadius, y: rect.height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: 0, y: smallRadius))
            path.addArc(center: CGPoint(x: smallRadius, y: smallRadius),
                       radius: smallRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        path.closeSubpath()
        return path
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    RemoteControlView(
        device: AppleTVDevice(
            id: "test",
            name: "Living Room",
            host: .name("test", nil),
            port: 49152
        )
    )
    .environmentObject(AppState())
    .frame(width: 400, height: 800)
    .background(Color.black)
}
