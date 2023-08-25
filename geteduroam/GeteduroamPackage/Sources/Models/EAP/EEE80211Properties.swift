import Foundation
import XMLCoder

public struct EEE80211Properties: Codable, Equatable {
    public init(ssid: String? = nil, consortiumOID: String? = nil, minRSNProto: IEEE80211RSNProtocol? = nil) {
        self.ssid = ssid
        self.consortiumOID = consortiumOID
        self.minRSNProto = minRSNProto
    }
    
    public let ssid: String?
    public let consortiumOID: String?
    public let minRSNProto: IEEE80211RSNProtocol?
    
    enum CodingKeys: String, CodingKey {
        case ssid = "SSID"
        case consortiumOID = "ConsortiumOID"
        case minRSNProto = "MinRSNProto"
    }
}
