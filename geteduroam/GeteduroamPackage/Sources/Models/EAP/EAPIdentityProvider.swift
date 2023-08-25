import Foundation
import XMLCoder

public struct EAPIdentityProvider: Codable, Equatable {
    public init(id: String, validUntil: Date? = nil, authenticationMethods: AuthenticationMethodList, credentialApplicability: CredentialApplicability, providerInfo: ProviderInfo? = nil) {
        self.id = id
        self.validUntil = validUntil
        self.authenticationMethods = authenticationMethods
        self.credentialApplicability = credentialApplicability
        self.providerInfo = providerInfo
    }
    
    public let id: String
    public let validUntil: Date?
    public let authenticationMethods: AuthenticationMethodList // at least 1!
    public let credentialApplicability: CredentialApplicability
    public let providerInfo: ProviderInfo?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case validUntil = "ValidUntil"
        case authenticationMethods = "AuthenticationMethods"
        case credentialApplicability = "CredentialApplicability"
        case providerInfo = "ProviderInfo"
    }
}
