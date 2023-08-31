import Foundation
import XMLCoder

public struct AuthenticationMethodList: Codable, Equatable {
    public init(methods: [AuthenticationMethod]) {
        self.methods = methods
    }
    
    public let methods: [AuthenticationMethod]
    
    enum CodingKeys: String, CodingKey {
        case methods = "AuthenticationMethod"
    }
}
