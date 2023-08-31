import Foundation
import XMLCoder

public struct InnerAuthenticationMethod: Codable, Equatable {
    public init(EAPMethod: EAPMethod? = nil, nonEAPAuthMethod: NonEAPAuthMethod? = nil, serverSideCredential: ServerCredential? = nil, clientSideCredential: ClientCredential? = nil) {
        self.EAPMethod = EAPMethod
        self.nonEAPAuthMethod = nonEAPAuthMethod
        self.serverSideCredential = serverSideCredential
        self.clientSideCredential = clientSideCredential
    }
    
    public let EAPMethod: EAPMethod?
    public let nonEAPAuthMethod: NonEAPAuthMethod?
    public let serverSideCredential: ServerCredential?
    public let clientSideCredential: ClientCredential?
    
    enum CodingKeys: String, CodingKey {
        case EAPMethod
        case nonEAPAuthMethod = "NonEAPAuthMethod"
        case serverSideCredential = "ServerSideCredential"
        case clientSideCredential = "ClientSideCredential"
    }
}
