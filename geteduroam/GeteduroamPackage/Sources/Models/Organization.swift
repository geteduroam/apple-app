import Foundation

public struct Organization: Codable, Identifiable, Equatable, Sendable {
    public init(id: String, name: [String: String]?, country: String, profiles: [Profile], geo: [Coordinate] = []) {
        self.id = id
        self.name = name
        self.country = country
        self.profiles = profiles
        self.geo = geo
        // For the language set during initialization we store the match words to improve query performance
        self.matchWordsLanguageCode = Locale.current.languageCode
        self.matchWords = Self.determineMatchWords(for: self.matchWordsLanguageCode, id: id, name: name)
    }
    
    public let id: String
    public let name: [String: String]?
    public let country: String
    public let profiles: [Profile]
    public let geo: [Coordinate]

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
    
    private static func determineMatchWords(for languageCode: String?, id: String, name: [String: String]?) -> [String] {
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
        self.name = try container.decodeIfPresent([String : String].self, forKey: .name)
        self.country = try container.decode(String.self, forKey: .country)
        self.profiles = try container.decode([Profile].self, forKey: .profiles)
        self.geo = try container.decode([Coordinate].self, forKey: .geo)
        // For the language set during initialization we store the match words to improve query performance
        self.matchWordsLanguageCode = Locale.current.languageCode
        self.matchWords = Self.determineMatchWords(for: self.matchWordsLanguageCode, id: id, name: name)
    }
    
    enum CodingKeys: CodingKey {
        case id
        case name
        case country
        case profiles
        case geo
    }
}

public extension [String: String] {
    func localized(for languageCode: String? = Locale.current.languageCode) -> String? {
        func fallback() -> String? {
            first(where: { $0.key == "any" })?.value
        }
        guard let language = languageCode else {
            return fallback()
        }
        return first(where: { $0.key == language })?.value ?? fallback()
    }
}
