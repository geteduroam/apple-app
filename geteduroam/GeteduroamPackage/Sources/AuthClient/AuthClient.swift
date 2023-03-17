import AppAuth
import Dependencies
import Foundation

public protocol AuthClient {
    func startAuth(request: OIDAuthorizationRequest) async throws -> OIDAuthState
}

extension DependencyValues {
    public var authClient: AuthClient {
        get { self[AuthClientKey.self] }
        set { self[AuthClientKey.self] = newValue }
    }
    
    public enum AuthClientKey: TestDependencyKey {
        public static var testValue = mockClient
    }
}

private let mockClient: AuthClient = FailingAuthClient()
