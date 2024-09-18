import Foundation
import XMLCoder

public struct CertificateData: Codable, Equatable, Sendable {
    public init(value: String, format: String, encoding: String) {
        self.value = value
        self.format = format
        self.encoding = encoding
    }
    
    public let value: String
    public let format: String
    public let encoding: String
    
    enum CodingKeys: String, CodingKey {
        case value = ""
        case format
        case encoding
    }
}
