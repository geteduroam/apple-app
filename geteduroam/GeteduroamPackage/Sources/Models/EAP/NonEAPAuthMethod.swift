import Foundation
import XMLCoder

public struct NonEAPAuthMethod: Codable, Equatable {
    public init(type: NonEAPAuthNumber) {
        self.type = type
    }
    
    public let type: NonEAPAuthNumber
  
    enum CodingKeys: String, CodingKey {
        case type = "Type"
    }
}
