import SwiftUI

/// Wraps SwiftUI's VerticalEdge.Set so it can be used on older OS versions.
public enum VerticalEdge {
    /// Corresponds to [Set](https://developer.apple.com/documentation/swiftui/verticaledge/set)
    public enum Set {
        /// Corresponds to [top](https://developer.apple.com/documentation/swiftui/verticaledge/set/top)
        case top
        
        /// Corresponds to [bottom](https://developer.apple.com/documentation/swiftui/verticaledge/set/bottom)
        case bottom
        
        /// Corresponds to [all](https://developer.apple.com/documentation/swiftui/verticaledge/set/all)
        case all
        
        @available(iOS 15.0, tvOS 15.0, watchOS 9.0, macOS 13.0, *)
        var original: SwiftUI.VerticalEdge.Set {
            switch self {
            case .top:
                return .top
                
            case .bottom:
                return .bottom
                
            case .all:
                return .all
                
            }
        }
    }
}

public extension Backport where Content: View {
    /// Configures the behavior in which scrollable content interacts with the software keyboard.
    /// - Parameter mode: Mode to apply
    /// - Returns: View with dismiss keyboard mode applied if available
    @ViewBuilder func listRowSeparatorTint(_ color: Color, edges: VerticalEdge.Set = .all) -> some View {
        if #available(iOS 15.0, tvOS 15.0, watchOS 9.0, macOS 13.0, *) {
            content.listRowSeparatorTint(color, edges: edges.original)
        } else {
            content
        }
    }
}
