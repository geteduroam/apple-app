import Foundation

public struct LocalizedEntry: Codable, Equatable, Sendable {
    public init(language: String? = "any", display: String) {
        self.language = language
        self.display = display
    }
    
    let language: String?
    let display: String
    
    enum CodingKeys: String, CodingKey {
        case language = "lang"
        case display
    }
}


extension [LocalizedEntry] {
    public func localized(for languageCode: String? = Locale.current.languageCode) -> String? {
        // When the requested language isn't there:
        // 1. find entry with language "any" or language not set
        // 2. use first entry
        func fallback() -> String? {
            first(where: { $0.language == "any" || $0.language == nil })?.display ?? first?.display
        }
        guard let language = languageCode else {
            return fallback()
        }
        return first(where: { $0.language == language })?.display ?? fallback()
    }
}
