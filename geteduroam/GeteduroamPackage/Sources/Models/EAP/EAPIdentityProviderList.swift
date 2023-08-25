import Foundation
import XMLCoder

// Definition: https://github.com/GEANT/CAT/blob/master/devices/xml/eap-metadata.xsd

public struct EAPIdentityProviderList: Codable, Equatable {
    public init(providers: [EAPIdentityProvider]) {
        self.providers = providers
    }
    
    public let providers: [EAPIdentityProvider]
    
    enum CodingKeys: String, CodingKey {
        case providers = "EAPIdentityProvider"
    }
}
