import SwiftUI

/// Wraps SwiftUI's Visibility so it can be used on older OS versions.
public enum Visibility {
    /// Corresponds to [automatic](https://developer.apple.com/documentation/swiftui/visibility/automatic)
    case automatic

    /// Corresponds to [visible](https://developer.apple.com/documentation/swiftui/visibility/visible)
    case visible

    /// Corresponds to [hidden](https://developer.apple.com/documentation/swiftui/visibility/hidden)
    case hidden

    @available(iOS 16.0, tvOS 16.0, watchOS 9.0, macOS 13.0, *)
    var original: SwiftUI.Visibility {
        switch self {
        case .automatic:
            return .automatic
        case .visible:
            return .visible
        case .hidden:
            return .hidden

        }
    }
}

public extension Backport where Content: View {
    /// Specifies the visibility of the background for scrollable views within this view.
    /// - Parameter mode: Mode to apply
    /// - Returns: View with background visibility applied if available
    @ViewBuilder func scrollContentBackground(_ mode: Visibility) -> some View {
        if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, macOS 13.0, *) {
            content.scrollContentBackground(mode.original)
        } else {
            content
        }
    }
}
