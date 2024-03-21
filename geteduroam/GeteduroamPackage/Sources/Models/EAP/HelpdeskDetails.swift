import Foundation
import XMLCoder

public struct HelpdeskDetails: Codable, Equatable, Sendable {
    public init(emailAdress: LocalizedString? = nil, webAddress: LocalizedString? = nil, phone: LocalizedString? = nil) {
        self.emailAdress = emailAdress
        self.webAddress = webAddress
        self.phone = phone
    }
    
    public let emailAdress: LocalizedString?
    public let webAddress: LocalizedString?
    public let phone: LocalizedString?
    
    enum CodingKeys: String, CodingKey {
        case emailAdress = "EmailAdress"
        case webAddress = "WebAddress"
        case phone = "Phone"
    }
}
