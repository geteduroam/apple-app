import Models
import SwiftUI

public struct ConnectButtonStyle: ButtonStyle {
    public init() { }
    
    @EnvironmentObject var theme: Theme
    
    private struct EnvironmentReaderView<Content: View>: View {
        let content: (Bool) -> Content
        
        @Environment(\.isEnabled) var isEnabled
        
        var body: some View {
            content(isEnabled)
        }
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        EnvironmentReaderView { isEnabled in
            configuration.label
                .padding()
                .padding(.horizontal, 24)
                .background(isEnabled ? Color("ConnectButton/Background") : Color("ConnectButton/DisabledBackground"))
                .foregroundColor(Color("ConnectButton/Foreground"))
                .font(theme.connectButtonFont)
                .clipShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: isEnabled)
        }
    }
}
