import MiniPlayerCore

extension ScreenAnchor {
    /// How the place is named in the menu and next to the grid.
    var menuTitle: String {
        switch self {
        case .topLeft: "Top - Left"
        case .top: "Center - Top"
        case .topRight: "Top - Right"
        case .left: "Center - Left"
        case .center: "Center"
        case .right: "Center - Right"
        case .bottomLeft: "Bottom - Left"
        case .bottom: "Center - Bottom"
        case .bottomRight: "Bottom - Right"
        }
    }

    /// The order of the Change Position menu, after "Custom".
    static let menuOrder: [ScreenAnchor] = [.center, .left, .right, .top, .bottom, .topLeft, .topRight, .bottomLeft, .bottomRight]
}
