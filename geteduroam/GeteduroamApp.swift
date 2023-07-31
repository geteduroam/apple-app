import AuthClient
import ComposableArchitecture
import Main
import Models
import SwiftUI

@main
struct GeteduroamApp: App {
    
    #if os(iOS)
    @UIApplicationDelegateAdaptor private var appDelegate: GeteduroamAppDelegate
    
    @StateObject var theme = Theme(
        searchFont: .custom("OpenSans-Regular", size: 20, relativeTo: .body),
        errorFont: .custom("OpenSans-Regular", size: 16, relativeTo: .body),
        organizationNameFont: .custom("OpenSans-Bold", size: 16, relativeTo: .body),
        organizationCountryFont: .custom("OpenSans-Regular", size: 11, relativeTo: .footnote),
        profilesHeaderFont: .custom("OpenSans-SemiBold", size: 12, relativeTo: .body),
        profileNameFont: .custom("OpenSans-Regular", size: 16, relativeTo: .body),
        connectButtonFont: .custom("OpenSans-Bold", size: 20, relativeTo: .body),
        connectedFont: .custom("OpenSans-Bold", size: 14, relativeTo: .body),
        infoHeaderFont: .custom("OpenSans-Bold", size: 14, relativeTo: .body),
        infoDetailFont: .custom("OpenSans-Regular", size: 14, relativeTo: .body))

    #elseif os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: GeteduroamAppDelegate

    @StateObject var theme = Theme(
        searchFont: .system(.body, design: .default),
        errorFont: .system(.body, design: .default),
        organizationNameFont: .system(.body, design: .default).bold(),
        organizationCountryFont: .system(.footnote, design: .default),
        profilesHeaderFont: .system(.body, design: .default).bold(),
        profileNameFont: .system(.body, design: .default),
        connectButtonFont: .system(.callout, design: .default).bold(),
        connectedFont: .system(.body, design: .default),
        infoHeaderFont: .system(.body, design: .default).bold(),
        infoDetailFont: .system(.body, design: .default))
    #endif
    
    var store: StoreOf<Main>!
    
    @Environment(\.openURL) var openURL
    
    init() {
#if os(macOS)
        fakeInitialWindowPositionPreference()
#endif

        store = .init(initialState: .init(), reducer: { Main() }, withDependencies: { [appDelegate] in
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
    // On macOS 13 and up using Window and .defaultPosition and .defaultSize would be better, but can't use control flow statement with 'SceneBuilder'
    var body: some Scene {
        WindowGroup("geteduroam", id: "mainWindow") {
            MainView(store: store)
                .environmentObject(theme)
                .onAppear {
                    DispatchQueue.main.async {
                        NSApplication.shared.windows.forEach { window in
                            window.standardWindowButton(.zoomButton)?.isEnabled = false
                        }
                    }
                }
                .frame(minWidth: 300, idealWidth: 540, maxWidth: .infinity, minHeight: 400, idealHeight: 640, maxHeight: .infinity, alignment: .center)
                .onDisappear {
                    // Quit app on close
                    NSApplication.shared.terminate(nil)
                }
        }
        .commands {
            // Avoid multiple windows
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
                EmptyView()
            }
            CommandGroup(replacing: CommandGroupPlacement.help) {
                Button("geteduroam Help") {
                    openURL(URL(string: "https://eduroam.org")!)
                }
            }
        }
    }
    
    private func fakeInitialWindowPositionPreference() {
        guard let main = NSScreen.main else {
            return
        }
        
        let key = "NSWindow Frame mainWindow-AppWindow-1"
        guard UserDefaults.standard.string(forKey: key) == nil else {
            return
        }
        
        let desiredWidth: CGFloat = 540
        let desiredHeight: CGFloat = 640
        
        let screenWidth = main.frame.width
        let screenHeightWithoutMenuBar = main.frame.height - 25 // menu bar
        let visibleFrame = main.visibleFrame

        let contentWidth = desiredWidth
        let contentHeight = desiredHeight + 54 // window title bar

        let windowX = visibleFrame.midX - contentWidth / 2
        let windowY = visibleFrame.midY - contentHeight / 2

        let newFramePreference = "\(Int(windowX)) \(Int(windowY)) \(Int(contentWidth)) \(Int(contentHeight)) 0 0 \(Int(screenWidth)) \(Int(screenHeightWithoutMenuBar))"
        UserDefaults.standard.set(newFramePreference, forKey: key)
    }
#endif
    
}
