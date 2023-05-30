import Foundation

public struct Institution: Codable, Identifiable, Equatable {
    public init(id: String, name: String, country: String, profiles: [Profile], geo: [Coordinate]) {
        self.id = id
        self.name = name
        self.country = country
        self.profiles = profiles
        self.geo = geo
    }
    
    public let id: String
    public let name: String?
    public let country: String
    public let profiles: [Profile]
    public let geo: [Coordinate]

    public var nameOrId: String {
        name ?? id
    }

    public var hasSingleProfile: Bool {
        profiles.count == 1
    }
    
    public var matchWords: [String] {
        var words = nameOrId.components(separatedBy: .alphanumerics.inverted).filter({ $0.isEmpty == false })
        let abbreviation = words.map({ $0.prefix(1) }).joined()
        words.append(nameOrId)
        words.append(abbreviation)
        return words
    }
}
