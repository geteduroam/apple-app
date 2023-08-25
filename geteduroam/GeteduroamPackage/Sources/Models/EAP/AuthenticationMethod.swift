import Foundation
import XMLCoder

public struct AuthenticationMethod: Codable, Equatable {
    public init(EAPMethod: EAPMethod, serverSideCredential: ServerCredential? = nil, clientSideCredential: ClientCredential? = nil, innerAuthenticationMethods: [InnerAuthenticationMethod]) {
        self.EAPMethod = EAPMethod
        self.serverSideCredential = serverSideCredential
        self.clientSideCredential = clientSideCredential
        self.innerAuthenticationMethods = innerAuthenticationMethods
    }
    
    public let EAPMethod: EAPMethod
    public let serverSideCredential: ServerCredential?
    public let clientSideCredential: ClientCredential?
    public let innerAuthenticationMethods: [InnerAuthenticationMethod]
    
    enum CodingKeys: String, CodingKey {
        case EAPMethod
        case serverSideCredential = "ServerSideCredential"
        case clientSideCredential = "ClientSideCredential"
        case innerAuthenticationMethods = "InnerAuthenticationMethod"
    }
}
