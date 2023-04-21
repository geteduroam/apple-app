import AuthClient
import ComposableArchitecture
import Main
import Models
import SwiftUI

@available(macOS 13, *)
@main
struct GeteduroamApp: App {
    
    #if os(iOS)
    @UIApplicationDelegateAdaptor private var appDelegate: GeteduroamAppDelegate
    
    @StateObject var theme = Theme(
        searchFont: .custom("OpenSans-Regular", size: 20, relativeTo: .body),
        errorFont: .custom("OpenSans-Regular", size: 16, relativeTo: .body),
        institutionNameFont: .custom("OpenSans-Bold", size: 16, relativeTo: .body),
        institutionCountryFont: .custom("OpenSans-Regular", size: 11, relativeTo: .footnote),
        profilesHeaderFont: .custom("OpenSans-SemiBold", size: 12, relativeTo: .body),
        profileNameFont: .custom("OpenSans-Regular", size: 16, relativeTo: .body),
        connectButtonFont: .custom("OpenSans-Bold", size: 20, relativeTo: .body),
        connectedFont: .custom("OpenSans-Bold", size: 14, relativeTo: .body),
        infoHeaderFont: .custom("OpenSans-Bold", size: 14, relativeTo: .body),
        infoDetailFont: .custom("OpenSans-Regular", size: 14, relativeTo: .body))

    #elseif os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: GeteduroamAppDelegate
    
    @StateObject var theme = Theme(
        searchFont: .system(.body, design: .default, weight: .regular),
        errorFont: .system(.body, design: .default, weight: .regular),
        institutionNameFont: .system(.body, design: .default, weight: .bold),
        institutionCountryFont: .system(.footnote, design: .default, weight: .regular),
        profilesHeaderFont: .system(.body, design: .default, weight: .bold),
        profileNameFont: .system(.body, design: .default, weight: .regular),
        connectButtonFont: .system(.callout, design: .default, weight: .bold),
        connectedFont: .system(.body, design: .default, weight: .regular),
        infoHeaderFont: .system(.body, design: .default, weight: .bold),
        infoDetailFont: .system(.body, design: .default, weight: .regular))
    #endif
    
    var store: StoreOf<Main>!
    
    @Environment(\.openURL) var openURL
    
    init() {
        store = .init(initialState: .init(), reducer: Main(), prepareDependencies: { [appDelegate] in
            $0.authClient = appDelegate
        })
    }
    
#if os(iOS)
    var body: some Scene {
        WindowGroup {
            MainView(store: store)
                .environmentObject(theme)
        }
    }
#elseif os(macOS)
    var body: some Scene {
        Window("geteduroam", id: "mainWindow") {
            MainView(store: store)
                .environmentObject(theme)
                .onAppear {
                    DispatchQueue.main.async {
                        NSApplication.shared.windows.forEach { window in
                            window.standardWindowButton(.zoomButton)?.isEnabled = false
                        }
                    }
                }
                .frame(minWidth: 300, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
        }
        .defaultPosition(.center)
        .defaultSize(width: 540, height: 640)
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.help) {
                Button("geteduroam Help") {
                    openURL(URL(string: "https://eduroam.org")!)
                }
            }
        }
    }
#endif
    
}
