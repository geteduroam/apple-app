import Foundation

public struct DiscoveryResponse: Codable, Equatable, Sendable {
    public init(content: DiscoveryVersion) {
        self.content = content
    }
    
    enum CodingKeys: String, CodingKey {
        case content = "http://letswifi.app/discovery#v3"
    }
    
    public let content: DiscoveryVersion
}
