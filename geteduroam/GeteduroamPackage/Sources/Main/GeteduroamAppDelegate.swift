@preconcurrency import AppAuth
import AuthClient
import ComposableArchitecture
import Foundation

public enum StartAuthError: Error {
    case noWindow
    case noRootViewController
    case unknownError
}

extension OIDAuthorizationRequest: @retroactive @unchecked Sendable { }

#if os(iOS)
@MainActor
public class GeteduroamAppDelegate: NSObject, UIApplicationDelegate, ObservableObject, AuthClient {
    
    public func createStore(initialState: Main.State) {
        assert(store == nil, "Call this method only once")
        store = .init(
            initialState: initialState,
            reducer: {
                Main()
            },
            withDependencies: {
                $0.authClient = self
            }
        )
    }
    
    public private(set) var store: StoreOf<Main>!
    
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
  
    public func startAuth(request: OIDAuthorizationRequest) async throws -> OIDAuthState {
        if UIApplication.shared.keyWindow == nil {
            // Sleep a bit to wait for a window to be created, as we might get called right at startup
            let duration = UInt64(2 * 1_000_000_000)
            try await Task.sleep(nanoseconds: duration)
        }
        guard let window = UIApplication.shared.keyWindow else {
            throw StartAuthError.noWindow
        }
        guard let presenter = window.rootViewController else {
            throw StartAuthError.noRootViewController
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: presenter) { authState, error in
                if let authState {
                    continuation.resume(returning: authState)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: StartAuthError.unknownError)
                }
            }
        }
    }

    public func application(_ application: UIApplication,
                            didFinishLaunchingWithOptions launchOptions:
                            [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        store.send(.applicationDidFinishLaunching)
        return true
    }
        
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Sends the URL to the current authorization flow (if any) which will process it if it relates to an authorization response.
        if let currentAuthorizationFlow, currentAuthorizationFlow.resumeExternalUserAgentFlow(with: url) {
            self.currentAuthorizationFlow = nil
            return true
        }
        
        return false
    }
}

extension UIApplication {
    
    var keyWindow: UIWindow? {
        // Get connected scenes
        return UIApplication.shared.connectedScenes
            // Keep only active scenes, onscreen and visible to the user
            .filter { $0.activationState == .foregroundActive }
            // Keep only the first `UIWindowScene`
            .first(where: { $0 is UIWindowScene })
            // Get its associated windows
            .flatMap({ $0 as? UIWindowScene })?.windows
            // Finally, keep only the key window
            .first(where: \.isKeyWindow)
    }
    
}
#elseif os(macOS)
import AuthenticationServices
@MainActor
public final class GeteduroamAppDelegate: NSObject, NSApplicationDelegate, ObservableObject, AuthClient {
    
    public func createStore(initialState: Main.State) {
        assert(store == nil, "Call this method only once")
        store = .init(
            initialState: initialState,
            reducer: {
                Main()
            },
            withDependencies: {
                $0.authClient = self
            }
        )
    }
    
    public private(set) var store: StoreOf<Main>!
    
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
  
    public func startAuth(request: OIDAuthorizationRequest) async throws -> OIDAuthState {
        guard let window = NSApplication.shared.keyWindow else {
            throw StartAuthError.noWindow
        }
        
        let customExternalUserAgent = CustomExternalUserAgent(presenting: window, presentationContextProvider: self)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, externalUserAgent: customExternalUserAgent) { authState, error in
                if let authState {
                    continuation.resume(returning: authState)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: StartAuthError.unknownError)
                }
            }
        }
    }
    
    public func applicationWillUpdate(_ notification: Notification) {
        if let menu = NSApplication.shared.mainMenu {
            menu.items.removeAll { $0.title == "View" } // TODO: Don't hardcode title
            // TODO: Also remove Zoom? menu.items.removeAll { $0.title == "Zoom" }
        }
    }
}

extension GeteduroamAppDelegate: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
#endif
