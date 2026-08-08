import Foundation

public enum AccessibilityID {
    public enum DeviceList {
        public static let headerIcon = "DeviceList_Header_AppIcon"
        public static let headerTitle = "DeviceList_Header_Title"
        public static let scanningProgress = "DeviceList_Progress_Scanning"
        public static let emptyStateIcon = "DeviceList_EmptyState_Icon"
        public static let emptyStateTitle = "DeviceList_EmptyState_Title"
        public static let scanButton = "DeviceList_EmptyState_ScanButton"
        public static let scrollView = "DeviceList_ScrollView"
        public static let errorBanner = "DeviceList_ErrorBanner"

        public static func deviceRow(_ id: String) -> String { "DeviceRow_\(id)" }
        public static func deviceName(_ id: String) -> String { "DeviceRow_\(id)_Name" }
        public static func pairButton(_ id: String) -> String { "DeviceRow_\(id)_PairButton" }
        public static func connectButton(_ id: String) -> String { "DeviceRow_\(id)_ConnectButton" }
        public static func unpairButton(_ id: String) -> String { "DeviceRow_\(id)_UnpairButton" }
    }

    public enum PinDialog {
        public static let container = "PinDialog_Container"
        public static let textField = "PinDialog_TextField"
        public static let cancelButton = "PinDialog_CancelButton"
        public static let connectButton = "PinDialog_ConnectButton"
    }

    public enum Remote {
        public static let view = "Remote_View"
        public static let backButton = "Remote_BackButton"
        public static let connectionIndicator = "Remote_ConnectionStatus_Indicator"
        public static let deviceName = "Remote_DeviceName"
        public static let powerButton = "Remote_PowerButton"
        public static let touchpad = "Remote_Touchpad"
        public static let menuButton = "Remote_MenuButton"
        public static let tvButton = "Remote_TVButton"
        public static let playPauseButton = "Remote_PlayPauseButton"
        public static let volumeUpButton = "Remote_VolumeUpButton"
        public static let volumeDownButton = "Remote_VolumeDownButton"
        public static let muteButton = "Remote_MuteButton"
    }

    public enum Paywall {
        public static let view = "Paywall_View"
        public static let subscribeButton = "Paywall_SubscribeButton"
        public static let restoreButton = "Paywall_RestoreButton"
        public static let demoButton = "Paywall_DemoButton"

        public static func offer(_ id: String) -> String { "Paywall_Offer_\(id)" }
    }

    public enum DemoBanner {
        public static let container = "DemoBanner_Container"
        public static let exitButton = "DemoBanner_ExitButton"
    }

    public enum NowPlaying {
        public static let section = "NowPlaying_Section"
        public static let trackTitle = "NowPlaying_TrackTitle"
        public static let trackArtist = "NowPlaying_TrackArtist"
    }
}
