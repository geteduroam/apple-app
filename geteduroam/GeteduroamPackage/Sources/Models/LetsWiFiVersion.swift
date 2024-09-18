import Foundation

public struct LetsWiFiVersion: Codable, Equatable, Sendable {
    public init(eapConfigEndpoint: URL? = nil, mobileConfigEndpoint: URL? = nil, authorizationEndpoint: URL? = nil, tokenEndpoint: URL? = nil) {
        self.eapConfigEndpoint = eapConfigEndpoint
        self.mobileConfigEndpoint = mobileConfigEndpoint
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
    }

    enum CodingKeys: String, CodingKey {
        case eapConfigEndpoint = "eapconfig_endpoint"
        case mobileConfigEndpoint = "mobileconfig_endpoint"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
    }
    
    public let eapConfigEndpoint: URL?
    public let mobileConfigEndpoint: URL?
    public let authorizationEndpoint: URL?
    public let tokenEndpoint: URL?
}
