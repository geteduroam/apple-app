import AppAuth
import AuthClient
import ComposableArchitecture
import EAPConfigurator
import Foundation
import Models
import SwiftUI
import XMLCoder

public struct Connect: Reducer {
    public let authClient: AuthClient
    
    public init(authClient: AuthClient = FailingAuthClient()) {
        self.authClient = authClient
    }
    
    public struct State: Equatable {
        public init(institution: Institution, loadingState: LoadingState = .initial, credentials: Credentials? = nil, destination: Destination.State? = nil) {
            self.institution = institution
            self.loadingState = loadingState
            self.credentials = credentials
            self.destination = destination
        }
        
        public let institution: Institution
        public var selectedProfileId: Profile.ID?
        
        public var providerInfo: ProviderInfo?
        public var agreedToTerms: Bool = false
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

        @PresentationState public var destination: Destination.State?
    }
    
    public indirect enum Action: Equatable {
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
        
        case connect
        case connectResponse(TaskResult<ProviderInfo?>)
        case destination(PresentationAction<Destination.Action>)
        case dismissPromptForCredentials
        case dismissTapped
        case logInButtonTapped
        case onAppear
        case select(Profile.ID)
        case startAgainTapped
        case updatePassword(String)
        case updateUsername(String)
        
        public enum Alert: Equatable { }
    }
    
    public struct Destination: Reducer {
        public enum State: Equatable {
            case alert(AlertState<AlertAction>)
            case termsAlert(AlertState<TermsAlertAction>)
        }
        
        public enum Action: Equatable {
            case alert(AlertAction)
            case termsAlert(TermsAlertAction)
        }
        
        public enum AlertAction: Equatable { }
        
        public enum TermsAlertAction: Equatable {
            case agreeButtonTapped
            case disagreeButtonTapped
            case readTermsButtonTapped
        }
        
        public var body: some Reducer<State, Action> {
            EmptyReducer()
        }
    }
    
    public enum InstitutionSetupError: Error {
        case missingAuthorizationEndpoint
        case missingTokenEndpoint
        case missingTermsAcceptance(ProviderInfo?)
        case noValidProviderFound(ProviderInfo?)
        case eapConfigurationFailed(EAPConfiguratorError, ProviderInfo?)
        case unknownError(Error, ProviderInfo?)
        
        var providerInfo: ProviderInfo? {
            switch self {
            case .missingAuthorizationEndpoint, .missingTokenEndpoint:
                return nil
            case let .missingTermsAcceptance(info), let .noValidProviderFound(info), let .eapConfigurationFailed(_, info), let .unknownError(_, info):
                return info
            }
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.openURL) var openURL
    
    private func connect(state: inout State) -> Effect<Connect.Action> {
        guard let profile = state.selectedProfile else {
            return .none
        }
        
        guard state.agreedToTerms || state.providerInfo?.localizedTermsOfUseURL == nil else {
            let termsAlert = AlertState<Destination.TermsAlertAction>(
                title: {
                    TextState("Terms of Use", bundle: .module)
                }, actions: {
                    ButtonState(action: .send(.readTermsButtonTapped)) {
                        TextState("Read Terms of Use")
                    }
                    ButtonState(action: .send(.agreeButtonTapped)) {
                        TextState("Agree")
                    }
                    ButtonState(role: .cancel, action: .send(.disagreeButtonTapped)) {
                        TextState("Disagree")
                    }
                }, message: {
                    TextState("You must agree to the terms of use before you can use this network.")
                })
            state.destination = .termsAlert(termsAlert)
            return .none
        }
        
        state.loadingState = .isLoading
        let credentials = state.credentials
        state.credentials = nil
        state.promptForCredentials = false
        let agreedToTerms = state.agreedToTerms
        return .task {
            await Action.connectResponse(TaskResult<ProviderInfo?> { try await connect(profile: profile, authClient: authClient, credentials: credentials, agreedToTerms: agreedToTerms) })
        }
    }
    
    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let _ = state.selectedProfile, state.institution.hasSingleProfile else {
                    return .none
                }
                // Auto connect if there is only a single profile
                return connect(state: &state)
                
            case let .destination(.presented(.termsAlert(action))):
                switch action {
                case .agreeButtonTapped:
                    state.agreedToTerms = true
                    return connect(state: &state)
                    
                case .disagreeButtonTapped:
                    state.loadingState = .initial
                    state.agreedToTerms = false
                    return .none
                    
                case .readTermsButtonTapped:
                    state.loadingState = .initial
                    return .run { [localizedTermsOfUseURL = state.providerInfo?.localizedTermsOfUseURL] _ in
                        guard let localizedTermsOfUseURL = localizedTermsOfUseURL else {
                            return
                        }
                        await openURL(localizedTermsOfUseURL)
                    }
                }
                
            case .destination:
                return .none
                
            case .dismissTapped:
                return .run { _ in
                    await dismiss()
                }
                
            case let .select(profileId):
                state.selectedProfileId = profileId
                return .none
                
            case .connect:
                return connect(state: &state)
                
            case let .connectResponse(.success(providerInfo)):
                state.loadingState = .success
                state.providerInfo = providerInfo
                return .none
                
            case let .connectResponse(.failure(InstitutionSetupError.missingTermsAcceptance(providerInfo))):
                state.providerInfo = providerInfo
                return connect(state: &state)
                
            case let .connectResponse(.failure(InstitutionSetupError.eapConfigurationFailed(EAPConfiguratorError.missingCredentials, providerInfo))):
                state.providerInfo = providerInfo
                state.promptForCredentials = true
                return .none
                
            case let .connectResponse(.failure(error)):
                // Read providerinfo if error has it so we can populate helpdesk
                state.providerInfo = (error as? InstitutionSetupError)?.providerInfo
                state.loadingState = .failure
                
                let nserror = error as NSError
                // Telling the user they cancelled isn't helping
                if nserror.domain == OIDGeneralErrorDomain && nserror.code == -3 {
                    return .none
                }
                let alert = AlertState<Destination.AlertAction>(
                    title: {
                        TextState("Failed to connect", bundle: .module)
                    }, actions: {
                    }, message: {
                        TextState((error as NSError).localizedDescription)
                    })
                state.destination = .alert(alert)
                return .none
                
            case .logInButtonTapped:
                // TODO: Check sanity of credentials
                return connect(state: &state)
                
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
                state.destination = nil
                state.loadingState = .initial
                return .none
                
            }
        }
        .ifLet(\.$destination, action: /Action.destination) {
          Destination()
        }
    }
    
    var decoder: XMLDecoder = {
        let decoder = XMLDecoder()
        decoder.shouldProcessNamespaces = true
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    @Dependency(\.date) var date
    
    func connect(profile: Profile, authClient: AuthClient, credentials: Credentials?, agreedToTerms: Bool) async throws -> ProviderInfo? {
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
            throw InstitutionSetupError.noValidProviderFound(providerList.providers.first?.providerInfo)
        }
        
        guard agreedToTerms || firstValidProvider.providerInfo?.localizedTermsOfUseURL == nil else {
            throw InstitutionSetupError.missingTermsAcceptance(firstValidProvider.providerInfo)
        }
        
        do {
            try await EAPConfigurator().configure(identityProvider: firstValidProvider, credentials: credentials)
        } catch let error as EAPConfiguratorError {
            throw InstitutionSetupError.eapConfigurationFailed(error, firstValidProvider.providerInfo)
        } catch {
            throw InstitutionSetupError.unknownError(error, firstValidProvider.providerInfo)
        }
        
        let info = SSID.fetchNetworkInfo()
        
        print("Info: \(String(describing: info))")
        // TODO: Check if connection works?
        
        return firstValidProvider.providerInfo
    }
    
}
