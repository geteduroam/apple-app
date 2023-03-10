import Foundation
import XMLCoder

public struct ProviderInfo: Codable, Equatable {
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

extension ProviderInfo {
    public var localizedTermsOfUseURL: URL? {
        guard let urlString = termsOfUse?.localized() else {
            return nil
        }
        return URL(string: urlString)
    }
}
