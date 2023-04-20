import Foundation
import NetworkExtension
#if os(iOS)
import SystemConfiguration.CaptiveNetwork
#elseif os(macOS)
import CoreWLAN
#endif

public class SSID {
#if os(iOS)
    public class func fetchNetworkInfo() -> [NetworkInfo] {
        if let interfaces: NSArray = CNCopySupportedInterfaces() {
            var networkInfos = [NetworkInfo]()
            for interface in interfaces {
                let interfaceName = interface as! String
                var networkInfo = NetworkInfo(
                    interface: interfaceName,
                    success: false,
                    ssid: nil,
                    bssid: nil
                )
                if let dict = CNCopyCurrentNetworkInfo(interfaceName as CFString) as NSDictionary? {
                    networkInfo.success = true
                    networkInfo.ssid = dict[kCNNetworkInfoKeySSID as String] as? String
                    networkInfo.bssid = dict[kCNNetworkInfoKeyBSSID as String] as? String
                }
                networkInfos.append(networkInfo)
            }
            return networkInfos
        }
        return []
    }
#elseif os(macOS)
    public class func fetchNetworkInfo() throws -> [NetworkInfo] {
        let interface = CWInterface()
        
        let set = try interface.scanForNetworks(withName: "eduroam", includeHidden: true)
        print("set \(set)")

        guard let interfaceName = interface.interfaceName else {
            return []
        }
        return [NetworkInfo(interface: interfaceName, success: true, ssid: interface.ssid(), bssid: interface.bssid())]
    }
#endif
}

public struct NetworkInfo {
    public var interface: String
    public var success: Bool
    public var ssid: String?
    public var bssid: String?
}
