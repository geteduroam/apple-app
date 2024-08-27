import ComposableArchitecture
import Models
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Connect

#if os(iOS)
final class ConnectViewPhoneTests: XCTestCase {

    override class func setUp() {
        SnapshotTesting.diffTool = "ksdiff"
    }
    
    let theme = Theme(
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
        versionFont: .system(.body, design: .default),
        statusFont: .system(.body, design: .default)
    )
    
    func testConnectScreen() throws {
        throw XCTSkip("Work in progress")
        let profile = Profile(id: "1", name: [LocalizedEntry(value: "My Profile")], default: true, type: .eapConfig)
        let organization = Organization(id: "test", name: [LocalizedEntry(value: "My Test Organization")], country: "AB", profiles: [profile], geo: [])
        let store = StoreOf<Connect>(initialState: .init(organization: organization), reducer: { })
        
        let connectView = ConnectView(store: store)
            .environmentObject(theme)
        
        let hosting = UIHostingController(rootView: connectView)

        assertSnapshot(of: hosting, as: .image(on: .iPadMini))
    }

}
#endif

#if os(macOS)
final class ConnectViewMacTests: XCTestCase {

    override class func setUp() {
        SnapshotTesting.diffTool = "ksdiff"
    }
    
    let theme = Theme(
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
    
    func testConnectScreenMac() throws {
        throw XCTSkip("Work in progress")
        let profile = Profile(id: "1", name: [LocalizedEntry(value: "My Profile")], default: true, type: .eapConfig)
        let organization = Organization(id: "test", name: [LocalizedEntry(value: "My Test Organization")], country: "AB", profiles: [profile], geo: [])
        let store = StoreOf<Connect>(initialState: .init(organization: organization), reducer: { })
        
        let connectView = ConnectView(store: store)
            .environmentObject(theme)
        
        let hosting = NSHostingController(rootView: connectView)
        hosting.view.frame = .init(origin: .zero, size: .init(width: 400, height: 640))
        
        assertSnapshot(of: hosting, as: .image)
    }

}
#endif
