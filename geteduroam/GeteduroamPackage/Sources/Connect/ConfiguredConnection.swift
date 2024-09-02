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
    public init(organizationId: String, profileId: String?, type: Connect.ConnectionType, validUntil: Date? = nil, providerInfo: ProviderInfo? = nil) {
        self.organizationId = organizationId
        self.profileId = profileId
        self.type = type
        self.validUntil = validUntil
        self.providerInfo = providerInfo
    }
    
    public let organizationId: String
    public let profileId: String?
    public let type: Connect.ConnectionType
    public let validUntil: Date?
    public let providerInfo: ProviderInfo?
}
