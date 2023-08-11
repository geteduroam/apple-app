import Dependencies
import Foundation
import NetworkExtension

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
        fetchCurrent: {
            NetworkInfo(ssid: "mock", bssid: "mock", signalStrength: 0.5, isSecure: true, didAutoJoin: false, didJustJoin: true, isChosenHelper: false)
        }
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
