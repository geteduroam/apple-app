import Foundation

public struct LocalizedEntry: Codable, Equatable, Sendable {
    public init(language: String? = "any", value: String) {
        self.language = language
        self.value = value
    }
    
    let language: String?
    let value: String
    
    enum CodingKeys: String, CodingKey {
        case value = ""
        case language = "lang"
    }
}


extension [LocalizedEntry] {
    public func localized(for languageCode: String? = Locale.current.languageCode) -> String? {
        func fallback() -> String? {
            first(where: { $0.language == "any" || $0.language == nil })?.value
        }
        guard let language = languageCode else {
            return fallback()
        }
        return first(where: { $0.language == language })?.value ?? fallback()
    }
}
