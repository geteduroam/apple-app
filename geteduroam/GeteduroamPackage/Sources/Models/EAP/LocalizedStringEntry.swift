import Foundation
import XMLCoder

public struct LocalizedStringEntry: Codable, Equatable, Sendable {
    public init(language: String? = nil, value: String) {
        self.language = language
        self.value = value
    }
    
    public let language: String?
    public let value: String
    
    enum CodingKeys: String, CodingKey {
        case language = "lang"
        case value = ""
    }
}
