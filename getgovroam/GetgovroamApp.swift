import AuthClient
import ComposableArchitecture
import Main
import Models
import SwiftUI

@main
struct GetgovroamApp: App {
    
    @UIApplicationDelegateAdaptor private var appDelegate: GeteduroamAppDelegate
    
    var store: StoreOf<Main>!
    
    init() {
        store = .init(initialState: .init(), reducer: Main(), prepareDependencies: { [appDelegate] in
            $0.authClient = appDelegate
        })
    }
    
    @StateObject var theme = Theme(
        searchFont: .body,
        errorFont: .body,
        organizationNameFont: .headline,
        organizationCountryFont: .footnote,
        profilesHeaderFont: .caption,
        profileNameFont: .body,
        connectButtonFont: .body,
        connectedFont: .body,
        infoHeaderFont: .body,
        infoDetailFont: .body)
    
	var body: some Scene {
		WindowGroup {
            MainView(store: store)
                .environmentObject(theme)
		}
	}
}
