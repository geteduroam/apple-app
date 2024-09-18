import CasePaths
import Foundation
@preconcurrency import URLRouting

public enum DiscoveryRoute: Equatable {
    case discover
}

public let discoveryRouter = OneOf {
    Route(.case(DiscoveryRoute.discover)) {
        Path { "discovery.json" }
    }
}
