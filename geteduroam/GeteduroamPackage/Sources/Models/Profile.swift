import Foundation

public struct Profile: Codable, Equatable, Identifiable {
    public init(id: String, name: [String : String]? = nil, `default`: Bool? = nil, eapconfig_endpoint: URL? = nil, mobileconfig_endpoint: URL? = nil, letswifi_endpoint: URL? = nil, webview_endpoint: URL? = nil, type: ProfileType? = nil) {
        self.id = id
        self.name = name
        self.`default` = `default`
        self.eapconfig_endpoint = eapconfig_endpoint
        self.mobileconfig_endpoint = mobileconfig_endpoint
        self.letswifi_endpoint = letswifi_endpoint
        self.webview_endpoint = webview_endpoint
        self.type = type
    }
    

    public let id: String
    public let name: [String: String]?
    public let `default`: Bool?
    public let eapconfig_endpoint: URL?
    public let mobileconfig_endpoint: URL?
    public let letswifi_endpoint: URL?
    public let webview_endpoint: URL?
    public let type: ProfileType?

    public var nameOrId: String {
        name?["any"] ?? id
    }
}

public enum ProfileType: String, Codable {
    case eapConfig = "eap-config"
    case letswifi
    case webview
}
