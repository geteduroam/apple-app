import Foundation
import XMLCoder

public struct LogoData: Codable, Equatable, Sendable {
    public init(value: String, mime: String, encoding: String) {
        self.value = value
        self.mime = mime
        self.encoding = encoding
    }
    
    public let value: String
    public let mime: String
    public let encoding: String
    
    enum CodingKeys: String, CodingKey {
        case value = ""
        case mime
        case encoding
    }
}
