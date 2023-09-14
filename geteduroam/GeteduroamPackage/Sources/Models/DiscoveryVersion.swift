import Foundation

public struct DiscoveryVersion: Codable, Equatable {
    public init(organizations: [Organization]) {
        self.organizations = organizations
    }
    
    enum CodingKeys: String, CodingKey {
        case organizations =  "institutions"
    }
    
    public let organizations: [Organization]
}

