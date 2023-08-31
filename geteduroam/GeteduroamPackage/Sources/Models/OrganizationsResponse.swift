import Foundation

<<<<<<< ours:geteduroam/GeteduroamPackage/Sources/Models/InstitutionsResponse.swift
public typealias InstitutionsResponse = [Institution]
=======
public struct OrganizationsResponse: Codable, Equatable {
    public init(instances: [Organization]) {
        self.instances = instances
    }
    
    public let instances: [Organization]
}
>>>>>>> theirs:geteduroam/GeteduroamPackage/Sources/Models/OrganizationsResponse.swift
