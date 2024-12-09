//  class CustomExternalUserAgent
//
//  This class provides a custom implementation of the OIDExternalUserAgent protocol,
//  specifically for handling authentication flows on macOS using AppAuth.
//
//  Problem Addressed:
//  On macOS, the default external user agent provided by AppAuth (`OIDExternalUserAgentMac`)
//  can result in crashes or unhandled errors in certain scenarios, such as:
//  - User cancelation of the authentication flow (e.g., closing the browser).
//  - Situations where AppAuth's callback handling (`callback(nil, authorizationError)`)
//    does not propagate errors correctly back to the application.
//
//  This class resolves these issues by providing a custom implementation that:
//  1. Utilizes ASWebAuthenticationSession directly for managing authentication flows.
//  2. Explicitly handles success, error, and cancelation cases.
//  3. Ensures that errors and cancelations are correctly propagated back to GeteduroamAppDelegate,
//     allowing the app to gracefully manage these situations.

//  Usage:
//  Replace `OIDExternalUserAgentMac` with `CustomExternalUserAgent` when creating an
//  authorization request for AppAuth.
//
//  Example:
//      let externalUserAgent = CustomExternalUserAgent(presenting: window)
//      OIDAuthState.authState(
//          byPresenting: request,
//          externalUserAgent: externalUserAgent
//      ) { authState, error in
//          // Handle authentication result
//      }

#if os(macOS)
import Foundation
@preconcurrency import AppAuth
import AuthenticationServices

public final class CustomExternalUserAgent: NSObject, OIDExternalUserAgent {
    
    private var presentingWindow: NSWindow?
    private var presentationContextProvider: ASWebAuthenticationPresentationContextProviding
    private var currentSession: OIDExternalUserAgentSession?

    public init(presenting window: NSWindow, presentationContextProvider: ASWebAuthenticationPresentationContextProviding) {
        self.presentingWindow = window
        self.presentationContextProvider = presentationContextProvider
    }

    public func present(_ request: OIDExternalUserAgentRequest, session: OIDExternalUserAgentSession) -> Bool {
        self.currentSession = session
        
        let authURL = request.externalUserAgentRequestURL()
        let scheme = request.redirectScheme()
        
        if let authURL {
            let authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
                if let callbackURL {
                    session.resumeExternalUserAgentFlow(with: callbackURL)
                } else if let error {
                    DispatchQueue.main.async {
                        session.failExternalUserAgentFlowWithError(error)
                    }
                }
            }
            authSession.presentationContextProvider = presentationContextProvider
            authSession.start()
            return true
        } else {
            return false
        }
    }

    public func dismiss(animated: Bool, completion: @escaping () -> Void) {
        currentSession = nil
        completion()
    }
}
#endif
