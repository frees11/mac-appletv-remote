import Foundation

public enum HIDUsagePage: UInt16, Sendable {
    case genericDesktop = 0x01
    case consumer = 0x0C
}

public enum HIDUsage: UInt16, Sendable {
    case up = 0x8C
    case down = 0x8D
    case left = 0x8B
    case right = 0x8A
    case select = 0x89
    case menu = 0x86
    case suspend = 0x82

    case playPause = 0xB0
    case pause = 0xB1
    case next = 0xB5
    case previous = 0xB6
    case tv = 0x60

    case volumeUp = 0xE9
    case volumeDown = 0xEA
}

public struct HIDKey: Sendable {
    public let usagePage: HIDUsagePage
    public let usage: HIDUsage

    public static let up = HIDKey(usagePage: .genericDesktop, usage: .up)
    public static let down = HIDKey(usagePage: .genericDesktop, usage: .down)
    public static let left = HIDKey(usagePage: .genericDesktop, usage: .left)
    public static let right = HIDKey(usagePage: .genericDesktop, usage: .right)
    public static let select = HIDKey(usagePage: .genericDesktop, usage: .select)
    public static let menu = HIDKey(usagePage: .genericDesktop, usage: .menu)
    public static let suspend = HIDKey(usagePage: .genericDesktop, usage: .suspend)

    public static let playPause = HIDKey(usagePage: .consumer, usage: .playPause)
    public static let pause = HIDKey(usagePage: .consumer, usage: .pause)
    public static let next = HIDKey(usagePage: .consumer, usage: .next)
    public static let previous = HIDKey(usagePage: .consumer, usage: .previous)
    public static let tv = HIDKey(usagePage: .consumer, usage: .tv)
    public static let volumeUp = HIDKey(usagePage: .consumer, usage: .volumeUp)
    public static let volumeDown = HIDKey(usagePage: .consumer, usage: .volumeDown)
}

public struct HIDEventBuilder {

    private static let timestampBytes: [UInt8] = [0x43, 0x89, 0x22, 0xCF, 0x08, 0x02, 0x00, 0x00]

    private static let paddingBytes: [UInt8] = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x02, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
        0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00
    ]

    private static let trailingBytes: [UInt8] = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00
    ]

    public static func buildEvent(key: HIDKey, pressed: Bool) -> Data {
        var data = Data()

        data.append(contentsOf: timestampBytes)
        data.append(contentsOf: paddingBytes)

        var usagePage = key.usagePage.rawValue.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &usagePage) { Array($0) })

        var usage = key.usage.rawValue.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &usage) { Array($0) })

        var down: UInt16 = pressed ? 1 : 0
        down = down.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &down) { Array($0) })

        data.append(contentsOf: trailingBytes)

        return data
    }

    public static func buildPressAndRelease(key: HIDKey) -> (press: Data, release: Data) {
        let press = buildEvent(key: key, pressed: true)
        let release = buildEvent(key: key, pressed: false)
        return (press, release)
    }

    public static func keyFromCommand(_ command: RemoteCommand) -> HIDKey {
        switch command {
        case .up, .longUp:
            return .up
        case .down, .longDown:
            return .down
        case .left, .longLeft:
            return .left
        case .right, .longRight:
            return .right
        case .select, .longSelect:
            return .select
        case .menu:
            return .menu
        case .home, .tv:
            return .tv
        case .topMenu:
            return .menu
        case .controlCenter:
            return .suspend
        case .playPause:
            return .playPause
        case .play:
            return .playPause
        case .pause:
            return .pause
        case .stop:
            return .pause
        case .next, .skipForward:
            return .next
        case .previous, .skipBackward:
            return .previous
        case .volumeUp:
            return .volumeUp
        case .volumeDown:
            return .volumeDown
        case .mute:
            return .volumeDown
        case .power, .powerOff:
            return .suspend
        }
    }
}
