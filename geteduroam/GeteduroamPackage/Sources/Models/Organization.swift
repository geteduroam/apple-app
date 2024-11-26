import Foundation

public struct Organization: Codable, Identifiable, Equatable, Sendable {
    public init(id: String, name: [LocalizedEntry]?, country: String, profiles: [Profile]) { //, geo: [Coordinate] = []) {
        self.id = id
        self.name = name
        self.country = country
        self.profiles = profiles
//        self.geo = geo
        // For the language set during initialization we store the match words to improve query performance
        self.matchWordsLanguageCode = Locale.current.languageCode
        self.matchWords = Self.determineMatchWords(for: self.matchWordsLanguageCode, id: id, name: name)
    }
    
    public let id: String
    public let name: [LocalizedEntry]?
    public let country: String
    public let profiles: [Profile]
//    public let geo: [Coordinate]

    public var nameOrId: String {
        name?.localized() ?? id
    }

    public var hasSingleProfile: Bool {
        profiles.count == 1
    }
    
    private let matchWords: [String]
    private let matchWordsLanguageCode: String?
    
    public func matchWords(for languageCode: String?) -> [String] {
        guard languageCode == matchWordsLanguageCode else {
            // In the unlikely case that the languages no longer match we redetermine the match words
            return Self.determineMatchWords(for: languageCode, id: id, name: name)
        }
        return matchWords
    }
    
    private static func determineMatchWords(for languageCode: String?, id: String, name: [LocalizedEntry]?) -> [String] {
        let nameOrId = name?.localized(for: languageCode) ?? id
        var words = nameOrId.components(separatedBy: .alphanumerics.inverted).filter({ $0.isEmpty == false })
        let abbreviation = words.map({ $0.prefix(1) }).joined()
        words.append(nameOrId)
        words.append(abbreviation)
        return words
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent([LocalizedEntry].self, forKey: .name)
        self.country = try container.decode(String.self, forKey: .country)
        self.profiles = try container.decode([Profile].self, forKey: .profiles)
//        self.geo = try container.decode([Coordinate].self, forKey: .geo)
        // For the language set during initialization we store the match words to improve query performance
        self.matchWordsLanguageCode = Locale.current.languageCode
        self.matchWords = Self.determineMatchWords(for: self.matchWordsLanguageCode, id: id, name: name)
    }
    
    public init?(query: String) {
        // If the query could be an URL, treat it as if it's a Let's Wifi URL
        let prefixedQuery: String
        if !query.lowercased().hasPrefix("https") {
            prefixedQuery = "https://" + query
        } else {
            prefixedQuery = query
        }
        let urlComponents = URLComponents(string: prefixedQuery)
        guard let url = urlComponents?.url, let host = urlComponents?.host, let scheme = urlComponents?.scheme, host.contains("."), scheme == "https" else {
            return nil
        }
        self.id = "url"
        self.name = [LocalizedEntry(value: host)]
        self.country = "URL"
        self.profiles = [Profile(id: "url", name: [LocalizedEntry(value: host)], default: true, letsWiFiEndpoint: url, type: .letswifi)]
//        self.geo = []
        // For the language set during initialization we store the match words to improve query performance
        self.matchWordsLanguageCode = Locale.current.languageCode
        self.matchWords = Self.determineMatchWords(for: self.matchWordsLanguageCode, id: id, name: name)
    }
    
    public init(local fileURL: URL) {
        let displayName = FileManager().displayName(atPath: fileURL.path)
        self.id = "local"
        self.name = [LocalizedEntry(value: displayName)]
        self.country = "FILE"
        self.profiles = [Profile(id: "local", name: [LocalizedEntry(value: displayName)], default: true, eapConfigEndpoint: fileURL, mobileConfigEndpoint: nil, letsWiFiEndpoint: nil, webviewEndpoint: nil, type: .eapConfig)]
//        self.geo = []
        // For the language set during initialization we store the match words to improve query performance
        self.matchWordsLanguageCode = Locale.current.languageCode
        self.matchWords = Self.determineMatchWords(for: self.matchWordsLanguageCode, id: id, name: name)
    }
    
    enum CodingKeys: CodingKey {
        case id
        case name
        case country
        case profiles
//        case geo
    }
}
