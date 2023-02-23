import Foundation

public struct Credentials: Equatable {
    public init(username: String = "", password: String = "") {
        self.username = username
        self.password = password
    }
    
    public var username: String
    public var password: String
}
