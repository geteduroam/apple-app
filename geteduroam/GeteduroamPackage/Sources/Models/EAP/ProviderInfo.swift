import Foundation
import XMLCoder

public struct ProviderInfo: Codable, Equatable {
    public init(displayName: LocalizedString? = nil, description: LocalizedString? = nil, providerLocations: [Location], providerLogo: LogoData? = nil, termsOfUse: LocalizedString? = nil, helpdesk: HelpdeskDetails? = nil) {
        self.displayName = displayName
        self.description = description
        self.providerLocations = providerLocations
        self.providerLogo = providerLogo
        self.termsOfUse = termsOfUse
        self.helpdesk = helpdesk
    }
    
    public let displayName: LocalizedString?
    public let description: LocalizedString?
    public let providerLocations: [Location]
    public let providerLogo: LogoData?
    public let termsOfUse: LocalizedString?
    public let helpdesk: HelpdeskDetails?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "DisplayName"
        case description = "Description"
        case providerLocations = "ProviderLocation"
        case providerLogo = "ProviderLogo"
        case termsOfUse = "TermsOfUse"
        case helpdesk = "Helpdesk"
    }
}

#if DEBUG
public let demoProviderInfo = ProviderInfo(displayName: [.init(language: nil, value: "Demo Provider")], description: [.init(language: "en", value: "English information about the demo provider.")], providerLocations: [.init(latitude: 12, longitude: 34)], providerLogo: nil, termsOfUse: [.init(language: "any", value: "You must behave yourself at all times.")], helpdesk: .init(emailAdress: [.init(language: "any", value: "hello@provider.info")], webAddress: [.init(language: "nl", value: "https://www.example.com/nl/"), .init(language: "any", value: "https://www.example.com/")], phone: [.init(language: nil, value: "+31551234567")]))
#endif
