import Foundation
import ComposableArchitecture
import Models

extension URL {
    static func connection() -> URL? {
        guard let directoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last else {
            return nil
        }
        let connectionURL = directoryURL.appendingPathComponent("configured_connection.json")
        return connectionURL
    }
}

extension PersistenceKey where Self == FileStorageKey<ConfiguredConnection?> {
    public static var connection: Self {
        guard let connectionURL = URL.connection() else {
            fatalError()
        }
        return fileStorage(connectionURL)
    }
}

public struct ConfiguredConnection: Codable, Equatable {
    public enum OrganizationType: Codable, Equatable {
        case id(String)
        case url(String)
        case local(URL)
    }
    
    public init(organizationType: OrganizationType, profileId: String?, type: Connect.ConnectionType?, validUntil: Date? = nil, providerInfo: ProviderInfo? = nil) {
        self.organizationType = organizationType
        self.profileId = profileId
        self.type = type
        self.validUntil = validUntil
        self.providerInfo = providerInfo
    }
    
    public let organizationType: OrganizationType
    public let profileId: String?
    public let type: Connect.ConnectionType?
    public let validUntil: Date?
    public let providerInfo: ProviderInfo?
    
    public func isConfigured(_ otherId: String, name: String) -> Bool {
        switch organizationType {
        case let .id(id):
            return id == otherId
        case let .url(urlString):
            guard let url = URL(string: urlString) else {
                return false
            }
            return "url" == otherId && url.host == name
        case let .local(fileURL):
            let displayName = FileManager().displayName(atPath: fileURL.path)
            return "local" == otherId && displayName == name
        }
    }
}
