import Dependencies
import Foundation
import NetworkExtension
import XCTestDynamicOverlay

public struct HotspotNetworkClient {
    public var fetchCurrent: () async -> NetworkInfo?
}

extension DependencyValues {
    public var hotspotNetworkClient: HotspotNetworkClient {
        get { self[HotspotNetworkClientKey.self] }
        set { self[HotspotNetworkClientKey.self] = newValue }
    }
    
    public enum HotspotNetworkClientKey: TestDependencyKey {
        public static var testValue = HotspotNetworkClient.mock
    }
}

extension HotspotNetworkClient {
    static var mock: Self = .init(
        fetchCurrent: unimplemented()
    )
}

extension DependencyValues.HotspotNetworkClientKey: DependencyKey {
    public static var liveValue = HotspotNetworkClient.live
}

extension HotspotNetworkClient {
    static var live: Self = .init(
        fetchCurrent: {
            #if os(iOS)
            guard let network = await NEHotspotNetwork.fetchCurrent() else {
                return nil
            }
            return NetworkInfo(ssid: network.ssid, bssid: network.bssid, signalStrength: network.signalStrength, isSecure: network.isSecure, didAutoJoin: network.didAutoJoin, didJustJoin: network.didJustJoin, isChosenHelper: network.isChosenHelper)
            #else
            fatalError("NetworkExtension not available")
            #endif
        }
    )
}

public struct NetworkInfo {
    public init(ssid: String, bssid: String, signalStrength: Double, isSecure: Bool, didAutoJoin: Bool, didJustJoin: Bool, isChosenHelper: Bool) {
        self.ssid = ssid
        self.bssid = bssid
        self.signalStrength = signalStrength
        self.isSecure = isSecure
        self.didAutoJoin = didAutoJoin
        self.didJustJoin = didJustJoin
        self.isChosenHelper = isChosenHelper
    }

    /// The SSID for the Wi-Fi network.
    public let ssid: String
    
    /// The BSSID for the Wi-Fi network.
    public let bssid: String

    /// The recent signal strength for the Wi-Fi network.
    public let signalStrength: Double
 
    /// Indicates whether the network is secure
    public let isSecure: Bool

    /// Indicates whether the network was joined automatically or was joined explicitly by the user.
    public let didAutoJoin: Bool

    /// Indicates whether the network was just joined.
    public let didJustJoin: Bool
    
    /// Indicates whether the calling Hotspot Helper is the chosen helper for this network.
    public let isChosenHelper: Bool
}
