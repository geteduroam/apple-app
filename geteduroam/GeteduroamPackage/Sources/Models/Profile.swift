import Foundation

public struct Profile: Codable, Equatable, Identifiable, Sendable {
    public init(id: String, name: [LocalizedEntry]? = nil, `default`: Bool? = nil, eapConfigEndpoint: URL? = nil, mobileConfigEndpoint: URL? = nil, letsWiFiEndpoint: URL? = nil, webviewEndpoint: String? = nil, type: ProfileType? = nil) {
        self.id = id
        self.name = name
        self.`default` = `default`
        self.eapConfigEndpoint = eapConfigEndpoint
        self.mobileConfigEndpoint = mobileConfigEndpoint
        self.letsWiFiEndpoint = letsWiFiEndpoint
        self.webviewEndpoint = webviewEndpoint
        self.type = type
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case `default`
        case eapConfigEndpoint = "eapconfig_endpoint"
        case mobileConfigEndpoint = "mobileconfig_endpoint"
        case letsWiFiEndpoint = "letswifi_endpoint"
        case webviewEndpoint = "webview_endpoint"
        case type
    }
    
    public let id: String
    public let name: [LocalizedEntry]?
    public let `default`: Bool?
    public let type: ProfileType?
    public let eapConfigEndpoint: URL?
    public let mobileConfigEndpoint: URL?
    public let letsWiFiEndpoint: URL?
    public let webviewEndpoint: String?
    
    public var nameOrId: String {
        name?.localized() ?? id
    }
}

public enum ProfileType: String, Codable, Sendable {
    case eapConfig = "eap-config"
    case letswifi
    case webview
}
