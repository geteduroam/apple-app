import AppAuth
import AuthClient
import ComposableArchitecture
import EAPConfigurator
import Foundation
import Models
import SwiftUI
import XMLCoder

public struct Connect: ReducerProtocol {
    public let authClient: AuthClient
    
    public init(authClient: AuthClient = FailingAuthClient()) {
        self.authClient = authClient
    }
    
    public struct State: Equatable {
        public init(institution: Institution, loadingState: LoadingState = .initial, credentials: Credentials? = nil) {
            self.institution = institution
            self.loadingState = loadingState
            self.credentials = credentials
        }
        
        public let institution: Institution
        public var selectedProfileId: Profile.ID?
        public var credentials: Credentials?
        public var promptForCredentials: Bool = false
        
        public var username: String {
            credentials?.username ?? ""
        }
        
        public var password: String {
            credentials?.password ?? ""
        }
        
        public var promptForCredentialsLoginDisabled: Bool {
            guard let credentials else {
                return true
            }
            return credentials.username.isEmpty || credentials.password.isEmpty
        }
        
        public var selectedProfile: Profile? {
            if let selectedProfileId {
                // Selected profile
                return institution.profiles.first(where: { $0.id == selectedProfileId })
            } else if let firstDefaultProfile = institution.profiles.first(where: { ($0.default ?? false) == true }) {
                // Otherwise the first default
                return firstDefaultProfile
            } else if let firstProfile = institution.profiles.first {
                // Otherwise the first
                return firstProfile
            } else {
                return nil
            }
        }
        
        public var canSelectProfile: Bool {
            switch loadingState {
            case .initial, .failure:
                return true
            case .isLoading, .success:
                return false
            }
        }
        
        public var isLoading: Bool {
            switch loadingState {
            case .initial, .failure, .success:
                return false
            case .isLoading:
                return true
            }
        }
        
        public var isConnected: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case .success:
                return true
            }
        }
        
        public enum LoadingState: Equatable {
            case initial
            case isLoading
            case success
            case failure
        }
        
        var loadingState: LoadingState
        var alert: AlertState<Action>?
    }
    
    public enum Action: Equatable {
        public static func == (lhs: Connect.Action, rhs: Connect.Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear):
                return true
            case let (.select(lhs), .select(rhs)):
                return lhs == rhs
            case (.connect, .connect):
                return true
            case (.connectResponse(.success), .connectResponse(.success)):
                return true
            case let (.connectResponse(.failure(lhs as NSError)), .connectResponse(.failure(rhs as NSError))):
                return lhs == rhs
            default:
                return false
            }
        }
        
        case onAppear
        case dismissTapped
        case select(Profile.ID)
        case connect
        case connectResponse(TaskResult<Void>)
        case dismissErrorTapped
        case startAgainTapped
        
        case updateUsername(String)
        case updatePassword(String)
        case dismissPromptForCredentials
    }
    
    public enum InstitutionSetupError: Error {
        case noProfile
        case missingAuthorizationEndpoint
        case missingTokenEndpoint
        case accessPointConfigurationFailed
        case noValidProviderFound
    }
    
    public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .onAppear:
            guard let profile = state.selectedProfile, state.institution.hasSingleProfile else {
                return .none
            }
            // Auto connect if there is only a single profile
            state.loadingState = .isLoading
            let credentials = state.credentials
            return .task {
                await Action.connectResponse(TaskResult<Void> { try await connect(profile: profile, authClient: authClient, credentials: credentials) })
            }
            
        case .dismissTapped:
            return .none
            
        case let .select(profileId):
            state.selectedProfileId = profileId
            return .none
            
        case .connect:
            guard let profile = state.selectedProfile else {
                return .none
            }
            state.loadingState = .isLoading
            let credentials = state.credentials
            state.credentials = nil
            state.promptForCredentials = false
            return .task {
                await Action.connectResponse(TaskResult<Void> { try await connect(profile: profile, authClient: authClient, credentials: credentials) })
            }
            
        case .connectResponse(.success):
            state.loadingState = .success
            return .none
            
        case .connectResponse(.failure(EAPConfiguratorError.missingCredentials)):
            print("prompt")
            state.promptForCredentials = true
            return .none
            
        case let .connectResponse(.failure(error)):
            state.loadingState = .failure
            
            let nserror = error as NSError
            // Telling the user they cancelled isn't helping
            if nserror.domain == OIDGeneralErrorDomain && nserror.code == -3 {
                return .none
            }
            
            state.alert = AlertState(
                title: .init(NSLocalizedString("Failed to connect", bundle: .module, comment: "Failed to connect")),
                message: .init((error as NSError).localizedDescription),
                dismissButton: .default(.init(NSLocalizedString("OK", bundle: .module, comment: "")), action: .send(.dismissErrorTapped))
            )
            return .none
            
        case .dismissErrorTapped:
            state.alert = nil
            return .none
            
        case .startAgainTapped:
            return .none
            
        case let .updateUsername(username):
            if let _ = state.credentials {
                state.credentials?.username = username
            } else {
                state.credentials = Credentials(username: username)
            }
            return .none
            
        case let .updatePassword(password):
            if let _ = state.credentials {
                state.credentials?.password = password
            } else {
                state.credentials = Credentials(password: password)
            }
            return .none
            
        case .dismissPromptForCredentials:
            state.promptForCredentials = false
            state.credentials = nil
            return .none

        }
    }
    
    var decoder: XMLDecoder = {
        let decoder = XMLDecoder()
        decoder.shouldProcessNamespaces = true
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    @Dependency(\.date) var date
    
    func connect(profile: Profile, authClient: AuthClient, credentials: Credentials?) async throws {
        let accessToken: String?
        if profile.oauth ?? false {
            guard let authorizationEndpoint = profile.authorization_endpoint else {
                throw InstitutionSetupError.missingAuthorizationEndpoint
            }
            guard let tokenEndpoint = profile.token_endpoint else {
                throw InstitutionSetupError.missingTokenEndpoint
            }
            let configuration = OIDServiceConfiguration(authorizationEndpoint: authorizationEndpoint, tokenEndpoint: tokenEndpoint)

            // Build authentication request
            let clientId = "app.eduroam.geteduroam"
            let scope = "eap-metadata"
            let redirectURL = URL(string: "app.eduroam.geteduroam:/")!
            let codeVerifier = OIDAuthorizationRequest.generateCodeVerifier()
            let codeChallange = OIDAuthorizationRequest.codeChallengeS256(forVerifier: codeVerifier)
            let state = UUID().uuidString
            let nonce = UUID().uuidString
         
            let request = OIDAuthorizationRequest(configuration: configuration, clientId: clientId, clientSecret: nil, scope: scope, redirectURL: redirectURL, responseType: OIDResponseTypeCode, state: state, nonce: nonce, codeVerifier: codeVerifier, codeChallenge: codeChallange, codeChallengeMethod: OIDOAuthorizationRequestCodeChallengeMethodS256, additionalParameters: nil)

            (accessToken, _) = try await authClient
                .startAuth(request: request)
                .tokens()
        } else {
            accessToken = nil
        }
        
        var urlRequest = URLRequest(url: profile.eapconfig_endpoint!)
        urlRequest.httpMethod = "POST"
        if let accessToken {
            urlRequest.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
        }

        let (eapConfigData, _) = try await URLSession.shared.data(for: urlRequest)
        
        let providerList = try decoder.decode(EAPIdentityProviderList.self, from: eapConfigData)
        let firstValidProvider = providerList
            .providers
            .first(where: { ($0.validUntil?.timeIntervalSince(date()) ?? 0) >= 0 })
        
        guard let firstValidProvider else {
            throw InstitutionSetupError.noValidProviderFound
        }
        
        do {
            try await EAPConfigurator().configure(identityProvider: firstValidProvider, credentials: credentials)
        } catch {
            throw error
        }
        
        let info = SSID.fetchNetworkInfo()
        
        print("Info: \(String(describing: info))")
        // TODO: Check if connection works?
    }
    
}
