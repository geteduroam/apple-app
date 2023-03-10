public typealias LocalizedString = [LocalizedStringEntry]

public extension LocalizedString {
    init(string: String) {
        self = [.init(language: nil, value: string)]
    }
}

import Foundation

public extension LocalizedString {
    func localized(for locale: Locale = Locale.current) -> String? {
        let fallback = first(where: { $0.language == nil })?.value
        guard let language = locale.languageCode else {
            return fallback
        }
        return first(where: { $0.language == language })?.value ?? fallback
    }
}
