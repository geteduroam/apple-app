import Foundation

public struct OrganizationsResponse: Codable, Equatable {
    public init(instances: [Organization]) {
        self.instances = instances
    }
    
    public let instances: [Organization]
}
