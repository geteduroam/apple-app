import Foundation
import XMLCoder

public struct EAPMethod: Codable, Equatable {
    public init(type: Int) {
        self.type = type
    }
    
    public let type: Int
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
    }
}
