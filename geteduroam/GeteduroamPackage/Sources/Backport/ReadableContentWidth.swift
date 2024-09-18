import SwiftUI

#if os(iOS)
import UIKit

// Source: https://mathijsbernson.nl/posts/using-readable-content-guides-in-swiftui/

// Not really a backport, since it isn't even available in the current SwiftUI, but who knows what iOS 17 brings…
@MainActor
struct ReadableContentWidth: ViewModifier {
    private let measureViewController = UIViewController()
    
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
    
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: readableWidth(for: orientation))
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                orientation = UIDevice.current.orientation
            }
    }
    
    private func readableWidth(for _: UIDeviceOrientation) -> CGFloat {
        measureViewController.view.frame = UIScreen.main.bounds
        let readableContentSize = measureViewController.view.readableContentGuide.layoutFrame.size
        return readableContentSize.width
    }
}

public extension Backport where Content: View {
    @MainActor @ViewBuilder
    func readableContentWidth() -> some View {
        content.modifier(ReadableContentWidth())
    }
}

// Similar approach, but with setting padding so that the background can still go full screen
struct ReadableContentWidthPadding: ViewModifier {
    private let measureViewController = UIViewController()
    
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
    
    func body(content: Content) -> some View {
        content
            .padding(readableWidthPadding(for: orientation))
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                orientation = UIDevice.current.orientation
            }
    }
    
    private func readableWidthPadding(for _: UIDeviceOrientation) -> EdgeInsets {
        // FIXME: This gives weird results in splitview on iPad
        let screenBounds = UIScreen.main.bounds
        measureViewController.view.frame = screenBounds
        let readableContentFrame = measureViewController.view.readableContentGuide.layoutFrame
        // On macOS odd things happen…
        if readableContentFrame.isEmpty {
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
        return EdgeInsets(
            top: -(screenBounds.maxY - readableContentFrame.maxY),
            leading: -(screenBounds.minX - readableContentFrame.minX),
            bottom: screenBounds.minY - readableContentFrame.minY,
            trailing: screenBounds.maxX - readableContentFrame.maxX)
    }
}

public extension Backport where Content: View {
    @MainActor @ViewBuilder
    func readableContentWidthPadding() -> some View {
        content.modifier(ReadableContentWidthPadding())
    }
}

struct SimplisticReadableContentWidth: ViewModifier {

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    func maxWidth(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall:
            600
        case .small:
            600
        case .medium:
            600
        case .large:
            600
        case .xLarge:
            720
        case .xxLarge:
            720
        case .xxxLarge:
            960
        case .accessibility1:
            960
        case .accessibility2:
            1024
        case .accessibility3:
            1024
        case .accessibility4:
            2048
        case .accessibility5:
            2048
        @unknown default:
            600
        }
    }
    
    func body(content: Content) -> some View {
        switch horizontalSizeClass {
        case .regular:
            HStack {
                Spacer()
                content
                    .frame(maxWidth: maxWidth(for: dynamicTypeSize))
                Spacer()
            }
        default:
            content
        }
    }
}

public extension Backport where Content: View {
    @ViewBuilder func simplisticReadableContentWidth() -> some View {
        content.modifier(SimplisticReadableContentWidth())
    }
}

#elseif os(macOS)
// Does nothing on macOS
public extension Backport where Content: View {
    @ViewBuilder func readableContentWidth() -> some View {
        content
    }
    
    @ViewBuilder func readableContentWidthPadding() -> some View {
        content
    }
    
    @ViewBuilder func simplisticReadableContentWidth() -> some View {
        content
    }
}
#endif
