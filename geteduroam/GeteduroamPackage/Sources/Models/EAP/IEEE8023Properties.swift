import Foundation
import XMLCoder

public struct IEEE8023Properties: Codable, Equatable {
    public init(networkID: String? = nil) {
        self.networkID = networkID
    }
    
    public let networkID: String?
    
    enum CodingKeys: String, CodingKey {
        case networkID = "NetworkID"
    }
}
