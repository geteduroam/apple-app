import Dependencies
import Foundation
import Models
import OSLog

public struct CacheClient {
    public var cacheDiscovery: (DiscoveryResponse) -> Void
    public var restoreDiscovery: () throws -> DiscoveryResponse
    
    static func cacheURLForDiscovery() throws -> URL {
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
        cacheDiscovery: { _ in
            print("Should now create cache")
        },
        restoreDiscovery: {
            print("Should now restore cache")
            return .init(content: .init(organizations: [.init(id: "restored", name: [.init(value: "Restored discovery from Cache")], country: "NL", profiles: [], geo: [])]))
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
        cacheDiscovery: { organizations in
            guard let data = try? JSONEncoder().encode(organizations), let cacheURL = try? Self.cacheURLForDiscovery() else {
                Logger.cache.error("Failed to cache discovery")
                return
            }
            try? data.write(to: cacheURL)
            Logger.cache.info("Cached discovery to \(cacheURL)")
        },
        restoreDiscovery: {
            do {
                let cacheURL = try Self.cacheURLForDiscovery()
                let data = try Data(contentsOf: cacheURL)
                let discovery = try JSONDecoder().decode(DiscoveryResponse.self, from: data)
                Logger.cache.info("Restored discovery from \(cacheURL)")
                return discovery
            } catch {
                Logger.cache.error("Restoring discovery failed \(error)")
                Logger.cache.warning("No discovery cache found, using bundled cache")
                guard let cacheURL = Bundle.main.url(forResource: "discovery", withExtension: "json") else {
                    Logger.cache.error("Failed to restore discovery from bundled cache")
                    throw CacheClientError.noCacheInBundle
                }
                let data = try Data(contentsOf: cacheURL)
                Logger.cache.info("Restored discovery from \(cacheURL)")
                let discovery = try JSONDecoder().decode(DiscoveryResponse.self, from: data)
                return discovery
            }
        })
}

enum CacheClientError: Error {
    case noDocumentsFolder
    case noCacheInBundle
}
