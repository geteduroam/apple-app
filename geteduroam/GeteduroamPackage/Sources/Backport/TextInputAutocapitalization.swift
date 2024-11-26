import SwiftUI

/// Wraps SwiftUI's ScrollDismissesKeyboardMode so it can be used on older OS versions.
public enum TextInputAutocapitalization {
    /// Corresponds to [characters](https://developer.apple.com/documentation/swiftui/textinputautocapitalization/characters)
    case characters

    /// Corresponds to [sentences](https://developer.apple.com/documentation/swiftui/textinputautocapitalization/sentences)
    case sentences

    /// Corresponds to [words](https://developer.apple.com/documentation/swiftui/textinputautocapitalization/words)
    case words

    /// Corresponds to [never](https://developer.apple.com/documentation/swiftui/textinputautocapitalization/never)
    case never

#if !os(macOS)
    @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var original: SwiftUI.TextInputAutocapitalization {
        switch self {
        case .characters:
            return .characters
        case .sentences:
            return .sentences
        case .words:
            return .words
        case .never:
            return .never
        }
    }
#endif
}

public extension Backport where Content: View {
    /// Configures the behavior in which scrollable content interacts with the software keyboard.
    /// - Parameter autocapitalization: Mode to apply
    /// - Returns: View with dismiss keyboard mode applied if available
    @ViewBuilder func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization?) -> some View {
#if !os(macOS)
        if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
            content.textInputAutocapitalization(autocapitalization?.original)
        } else {
            content
        }
#else
        content
#endif
    }
}
