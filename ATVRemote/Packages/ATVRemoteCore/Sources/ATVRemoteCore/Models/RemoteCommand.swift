import Foundation

public enum RemoteCommand: String, Sendable, CaseIterable {
    case up
    case down
    case left
    case right
    case select

    case longUp = "long_up"
    case longDown = "long_down"
    case longLeft = "long_left"
    case longRight = "long_right"
    case longSelect = "long_select"

    case menu
    case home
    case topMenu = "top_menu"
    case tv
    case controlCenter = "control_center"

    case playPause = "play_pause"
    case play
    case pause
    case stop
    case next
    case previous
    case skipForward = "skip_forward"
    case skipBackward = "skip_backward"

    case volumeUp = "volume_up"
    case volumeDown = "volume_down"
    case mute

    case power
    case powerOff = "power_off"

    public var isLongPress: Bool {
        switch self {
        case .longUp, .longDown, .longLeft, .longRight, .longSelect:
            return true
        default:
            return false
        }
    }

    public var shortPressVariant: RemoteCommand? {
        switch self {
        case .longUp: return .up
        case .longDown: return .down
        case .longLeft: return .left
        case .longRight: return .right
        case .longSelect: return .select
        default: return nil
        }
    }
}
