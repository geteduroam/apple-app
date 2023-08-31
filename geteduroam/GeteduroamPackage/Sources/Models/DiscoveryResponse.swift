import Foundation

public struct DiscoveryResponse: Codable, Equatable {
    public init(content: DiscoveryVersion) {
        self.content = content
    }
    
    enum CodingKeys: String, CodingKey {
        case content = "http://letswifi.app/discovery#v2"
    }
    
    public let content: DiscoveryVersion
}
