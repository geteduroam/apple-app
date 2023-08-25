import Foundation
import XMLCoder

public struct CredentialApplicability: Codable, Equatable {
    public init(IEEE80211: [EEE80211Properties], IEEE8023: [IEEE8023Properties]) {
        self.IEEE80211 = IEEE80211
        self.IEEE8023 = IEEE8023
    }
    
    public let IEEE80211: [EEE80211Properties]
    public let IEEE8023: [IEEE8023Properties]
    
    enum CodingKeys: String, CodingKey {
        case IEEE80211
        case IEEE8023
    }
}

