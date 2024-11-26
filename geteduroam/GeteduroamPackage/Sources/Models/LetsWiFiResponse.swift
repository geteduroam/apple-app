import Foundation

public struct LetsWiFiResponse: Codable, Equatable {
    public init(content: LetsWiFiVersion) {
        self.content = content
    }
    
    enum CodingKeys: String, CodingKey {
        case content = "http://letswifi.app/api#v3"
    }
    
    public let content: LetsWiFiVersion
}
