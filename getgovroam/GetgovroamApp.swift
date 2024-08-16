import AuthClient
import ComposableArchitecture
import Main
import Models
import SwiftUI

#if os(iOS)
extension Theme {
    
    @MainActor
    static var theme = Theme(
        searchFont: .custom("Muli", size: 20, relativeTo: .body),
        errorFont: .custom("Muli", size: 16, relativeTo: .body),
        organizationNameFont: .custom("Muli-Bold", size: 16, relativeTo: .body),
        organizationCountryFont: .custom("Muli", size: 11, relativeTo: .footnote),
        profilesHeaderFont: .custom("Muli-SemiBold", size: 12, relativeTo: .body),
        profileNameFont: .custom("Muli", size: 16, relativeTo: .body),
        connectButtonFont: .custom("Muli-Bold", size: 20, relativeTo: .body),
        connectedFont: .custom("Muli-Bold", size: 14, relativeTo: .body),
        infoHeaderFont: .custom("Muli-Bold", size: 14, relativeTo: .body),
        infoDetailFont: .custom("Muli", size: 14, relativeTo: .body),
        versionFont: .custom("Muli", size: 9, relativeTo: .caption2)
        )
}
#elseif os(macOS)
extension Theme {
    
    @MainActor
    static var theme =  Theme(
        searchFont: .system(.body, design: .default),
        errorFont: .system(.body, design: .default),
        organizationNameFont: .system(.body, design: .default).bold(),
        organizationCountryFont: .system(.footnote, design: .default),
        profilesHeaderFont: .system(.body, design: .default).bold(),
        profileNameFont: .system(.body, design: .default),
        connectButtonFont: .system(.callout, design: .default).bold(),
        connectedFont: .system(.body, design: .default),
        infoHeaderFont: .system(.body, design: .default).bold(),
        infoDetailFont: .system(.body, design: .default),
        versionFont: .system(.body, design: .default)
    )
}
#endif

@main
struct GeteduroamApp: App {
    
#if os(iOS)
    @UIApplicationDelegateAdaptor private var appDelegate: GeteduroamAppDelegate
#elseif os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: GeteduroamAppDelegate
#endif
    
    @StateObject var theme = Theme.theme
    
    @Environment(\.openURL) var openURL
    
    init() {
#if os(macOS)
        fakeInitialWindowPositionPreference()
#endif
      
#if DEBUG
        let initialState: Main.State
        if let scenario = UserDefaults.standard.string(forKey: "Scenario"),  let scenario = Scenario(rawValue: scenario) {
            initialState = scenario.initialState
        } else {
            initialState = .init()
        }
#else
        let initialState = Main.State()
#endif
        
        appDelegate.createStore(initialState: initialState)
    }
    
#if os(iOS)
    var body: some Scene {
        WindowGroup {
            MainView(store: appDelegate.store)
                .environmentObject(theme)
        }
    }
#elseif os(macOS)
    // On macOS 13 and up using Window and .defaultPosition and .defaultSize would be better, but can't use control flow statement with 'SceneBuilder'
    var body: some Scene {
        WindowGroup("getgovroam", id: "mainWindow") {
            MainView(store: appDelegate.store)
                .environmentObject(theme)
                .frame(minWidth: 300, idealWidth: 540, maxWidth: .infinity, minHeight: 460, idealHeight: 640, maxHeight: .infinity, alignment: .center)
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
                Button("getgovroam Help") {
                    openURL(URL(string: "https://govroam.nl")!)
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
