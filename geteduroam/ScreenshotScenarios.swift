import Foundation
import Main
import Models

#if DEBUG
extension Organization {
    static let example = Organization(
        id: "id",
        name: [
            .init(language: "any", value: "Example Organization (demo)"),
            .init(language: "nl", value: "Voorbeeldorganisatie (demo)")
        ],
        country: "NL",
        profiles: [
            .init(
                id: "profile1",
                name: [
                    .init(language: "any", value: "Profile for Staff"),
                    .init(language: "nl", value: "Profiel voor medewerkers")
                ],
                default: true,
                type: .eapConfig
            ),
            .init(
                id: "profile2",
                name: [
                    .init(language: "any", value: "Profile for Students"),
                    .init(language: "nl", value: "Profiel voor studenten")
                ],
                default: true,
                type: .eapConfig
            )
        ],
        geo: []
    )
    
    static let example2 = Organization(
        id: "id2",
        name: [
            .init(language: "any", value: "eduroam (demo)"),
            .init(language: "nl", value: "eduroam (demo)")
        ],
        country: "WW",
        profiles: [],
        geo: []
    )
    
    static let example3 = Organization(
        id: "id3",
        name: [
            .init(language: "any", value: "Another Organization (demo)"),
            .init(language: "nl", value: "Andere Organisatie (demo)")
        ],
        country: "NL",
        profiles: [],
        geo: []
    )
}

extension ProviderInfo {
    static let example = ProviderInfo(
        displayName: [
            .init(language: "any", value: "Example Organization"),
            .init(language: "nl", value: "Voorbeeldorganisatie")
        ],
        description: [
            .init(language: "any", value: "Contact our helpdesk if you need assistance."),
            .init(language: "nl", value: "Benader onze helpdesk als je hulp nodig hebt.")
        ],
        providerLocations: [], providerLogo: nil, termsOfUse: nil, helpdesk: HelpdeskDetails(emailAdress: [
            .init(language: "any", value: "helpdesk@example.com")
        ], webAddress: [
            .init(language: "any", value: "https://www.example.com/helpdesk")
        ]))
}

enum Scenario: String, CaseIterable {
    case main
    case search
    case connect
    case connected
    
    var initialState: Main.State {
        switch self {
        case .main:
            Main.State(
                organizations: .init(uniqueElements: [.example, .example2, .example3]),
                loadingState: .success
            )
            
        case .search:
            Main.State(
                searchQuery: "demo",
                organizations: .init(uniqueElements: [.example, .example2, .example3]),
                loadingState: .success,
                searchResults:  .init(uniqueElements: [.example, .example2, .example3])
            )
            
        case .connect:
            Main.State(
                loadingState: .success,
                destination: .connect(
                    .init(
                        organization: .example,
                        providerInfo: .example
                    )
                ))
            
        case .connected:
            Main.State(
                loadingState: .success,
                destination: .connect(
                    .init(
                        organization: .example,
                        loadingState: .success(.connected, .ssids(expectedSSIDs: ["eduroam"]), validUntil: nil),
                        providerInfo: .example
                    )
                ))
        }
    }
}
#endif
