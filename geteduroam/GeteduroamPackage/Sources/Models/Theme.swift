import SwiftUI

public class Theme: ObservableObject {
    @Published public var searchFont: Font
    @Published public var errorFont: Font
    @Published public var institutionNameFont: Font
    @Published public var institutionCountryFont: Font
    @Published public var profilesHeaderFont: Font
    @Published public var profileNameFont: Font
    @Published public var connectButtonFont: Font
    @Published public var connectedFont: Font
    
    public init(searchFont: Font, errorFont: Font, institutionNameFont: Font, institutionCountryFont: Font, profilesHeaderFont: Font, profileNameFont: Font, connectButtonFont: Font, connectedFont: Font) {
        self.searchFont = searchFont
        self.errorFont = errorFont
        self.institutionNameFont = institutionNameFont
        self.institutionCountryFont = institutionCountryFont
        self.profilesHeaderFont = profilesHeaderFont
        self.profileNameFont = profileNameFont
        self.connectButtonFont = connectButtonFont
        self.connectedFont = connectedFont
    }
}

extension Theme {
    public static var demo = Theme(
        searchFont: .custom("OpenSans-Regular", size: 20, relativeTo: .body),
        errorFont: .custom("OpenSans-Regular", size: 16, relativeTo: .body),
        institutionNameFont: .custom("OpenSans-Bold", size: 16, relativeTo: .body),
        institutionCountryFont: .custom("OpenSans-Regular", size: 11, relativeTo: .footnote),
        profilesHeaderFont: .custom("OpenSans-SemiBold", size: 12, relativeTo: .body),
        profileNameFont: .custom("OpenSans-Regular", size: 16, relativeTo: .body),
        connectButtonFont: .custom("OpenSans-Bold", size: 20, relativeTo: .body),
        connectedFont: .custom("OpenSans-Bold", size: 14, relativeTo: .body))
    
}
