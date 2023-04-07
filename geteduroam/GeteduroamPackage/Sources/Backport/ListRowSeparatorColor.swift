import SwiftUI

public extension Backport where Content: View {
    /// Configures the behavior in which scrollable content interacts with the software keyboard.
    /// - Parameter mode: Mode to apply
    /// - Returns: View with dismiss keyboard mode applied if available
    @ViewBuilder func listRowSeparatorTint(_ color: Color, edges: VerticalEdge.Set = .all) -> some View {
        if #available(iOS 15.0, tvOS 15.0, watchOS 9.0, macOS 13.0, *) {
            content.listRowSeparatorTint(color, edges: edges)
        } else {
            content
        }
    }
}
