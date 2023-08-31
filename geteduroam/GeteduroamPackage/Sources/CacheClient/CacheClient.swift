import Dependencies
import Foundation
import Models
import OSLog

public struct CacheClient {
    public var cacheOrganizations: (OrganizationsResponse) -> Void
    public var restoreOrganizations: () throws -> OrganizationsResponse
    
    static func cacheURLForOrganizations() throws -> URL {
        guard let directoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last else {
            throw CacheClientError.noDocumentsFolder
        }
        let cacheURL = directoryURL.appendingPathComponent("discovery.json")
        return cacheURL
    }
}

extension DependencyValues {
    public var cacheClient: CacheClient {
        get { self[CacheClientKey.self] }
        set { self[CacheClientKey.self] = newValue }
    }
    
    public enum CacheClientKey: TestDependencyKey {
        public static var testValue = CacheClient.mock
    }
}

extension CacheClient {
    static var mock: Self = .init(
        cacheOrganizations: { _ in
            print("Should now create cache")
        },
        restoreOrganizations: {
            print("Should now restore cache")
            return OrganizationsResponse(instances: [.init(id: "restored", name: "Restored Organization from Cache", country: "NL", cat_idp: 0, profiles: [], geo: [])])
        })
}

extension DependencyValues.CacheClientKey: DependencyKey {
    public static var liveValue = CacheClient.live
}

extension Logger {
  static var cache = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CacheClient", category: "cache")
}

extension CacheClient {
    static var live: Self = .init(
        cacheOrganizations: { organizations in
            guard let data = try? JSONEncoder().encode(organizations), let cacheURL = try? Self.cacheURLForOrganizations() else {
                Logger.cache.error("Failed to cache organizations")
                return
            }
            try? data.write(to: cacheURL)
            Logger.cache.info("Cached organizations to \(cacheURL)")
        },
        restoreOrganizations: {
            do {
                let cacheURL = try Self.cacheURLForOrganizations()
                let data = try Data(contentsOf: cacheURL)
                let organizations = try JSONDecoder().decode(OrganizationsResponse.self, from: data)
                Logger.cache.info("Restored organizations from \(cacheURL)")
                return organizations
            } catch {
                Logger.cache.warning("No organizations cache found, using bundled cache")
                guard let cacheURL = Bundle.main.url(forResource: "discovery", withExtension: "json") else {
                    Logger.cache.error("Failed to restore organizations from bundled cache")
                    throw CacheClientError.noCacheInBundle
                }
                let data = try Data(contentsOf: cacheURL)
                Logger.cache.info("Restored organizations from \(cacheURL)")
                let organizations = try JSONDecoder().decode(OrganizationsResponse.self, from: data)
                return organizations
            }
        })
}

enum CacheClientError: Error {
    case noDocumentsFolder
    case noCacheInBundle
}
