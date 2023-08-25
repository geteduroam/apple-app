import AppAuth
import AuthClient
import ComposableArchitecture
import EAPConfigurator
import Foundation
import HotspotNetworkClient
import Models
import NotificationClient
import SwiftUI
import XMLCoder

public struct Connect: Reducer {
    public init() { }
    
    public struct State: Equatable {
        public init(organization: Organization, selectedProfileId: Profile.ID? = nil, autoConnectOnAppear: Bool = false, loadingState: LoadingState = .initial, credentials: Credentials? = nil, destination: Destination.State? = nil) {
            self.organization = organization
            self.selectedProfileId = selectedProfileId
            self.autoConnectOnAppear = autoConnectOnAppear
            self.loadingState = loadingState
            self.credentials = credentials
            self.destination = destination
        }
        
        public let organization: Organization
        public var selectedProfileId: Profile.ID?
        public var autoConnectOnAppear: Bool

        public var providerInfo: ProviderInfo?
        public var agreedToTerms: Bool = false
        public var credentials: Credentials?
        public var accessToken: String?
        public var requiredUserNameSuffix: String? = nil
        public var promptForCredentials: Bool = false
        
        public var username: String {
            credentials?.username ?? ""
        }
        
        public var usernamePrompt: String {
            if let requiredUserNameSuffix {
                return NSLocalizedString("Username", bundle: .module, comment: "") + "@" + requiredUserNameSuffix
            } else {
                return NSLocalizedString("Username", bundle: .module, comment: "")
            }
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
                return organization.profiles.first(where: { $0.id == selectedProfileId })
            } else if let firstDefaultProfile = organization.profiles.first(where: { ($0.default ?? false) == true }) {
                // Otherwise the first default
                return firstDefaultProfile
            } else if let firstProfile = organization.profiles.first {
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
        
        public var isConfigured: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case .success:
                return true
            }
        }
        
        public var isConfiguredAndConnected: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case let .success(connected):
                return connected == .connected
            }
        }
        
        public var isConfiguredButConnectionUnknown: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case let .success(connected):
                return connected == .unknown
            }
        }
        
        public var isConfiguredButDisconnected: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case let .success(connected):
                return connected == .disconnected
            }
        }
        
        public enum LoadingState: Equatable {
            case initial
            case isLoading
            case success(ConnectionState)
            case failure
        }
        
        var loadingState: LoadingState

        @PresentationState public var destination: Destination.State?
    }
    
    public enum ConnectResult: Equatable {
        case verified(credentials: Credentials?, accessToken: String?)
        case applied(ConnectionType)
    }
    
    public enum ConnectionType: Equatable {
        case ssids(expectedSSIDs: [String])
        case hotspot20
    }
    
    public struct ConnectResponse: Equatable {
        public init(providerInfo: ProviderInfo? = nil, result: Connect.ConnectResult) {
            self.providerInfo = providerInfo
            self.result = result
        }
        
        public let providerInfo: ProviderInfo?
        public let result: Connect.ConnectResult
    }
    
    public enum ConnectionState {
        case unknown
        case disconnected
        case connected
    }

    public indirect enum Action: Equatable {
        case connect
        case connectResponse(TaskResult<ConnectResponse>)
        case destination(PresentationAction<Destination.Action>)
        case dismissPromptForCredentials
        case dismissTapped
        case foundSSID(String)
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
        }
        
        public var body: some Reducer<State, Action> {
            EmptyReducer()
        }
    }
    
    public enum OrganizationSetupError: Error, LocalizedError, Equatable {
        public static func == (lhs: Connect.OrganizationSetupError, rhs: Connect.OrganizationSetupError) -> Bool {
            (lhs as NSError) == (rhs as NSError)
        }
        
        case missingAuthorizationEndpoint
        case missingTokenEndpoint
        case missingEAPConfigEndpoint
        case missingTermsAcceptance(ProviderInfo?)
        case noValidProviderFound(ProviderInfo?)
        case eapConfigurationFailed(EAPConfiguratorError, ProviderInfo?)
        case mobileConfigFailed(ProviderInfo?)
        case userCancelled(ProviderInfo?)
        case unknownError(Error, ProviderInfo?)
        
        var providerInfo: ProviderInfo? {
            switch self {
            case .missingAuthorizationEndpoint, .missingTokenEndpoint, .missingEAPConfigEndpoint:
                return nil
            case let .missingTermsAcceptance(info), let .noValidProviderFound(info), let .eapConfigurationFailed(_, info), let .mobileConfigFailed(info), let .userCancelled(info), let .unknownError(_, info):
                return info
            }
        }
 
        public var errorDescription: String? {
            switch self {
            case .missingAuthorizationEndpoint:
                return NSLocalizedString("Missing information to start authentication.", bundle: .module, comment: "missingAuthorizationEndpoint")
                
            case .missingTokenEndpoint:
                return NSLocalizedString("Missing information to start authentication.", bundle: .module, comment: "missingTokenEndpoint")
                
            case .missingEAPConfigEndpoint:
                return NSLocalizedString("Missing information to start configuration.", bundle: .module, comment: "missingEAPConfigEndpoint")
                
            case .missingTermsAcceptance:
                return NSLocalizedString("You must agree to the terms of use.", bundle: .module, comment: "missingTermsAcceptance")
                
            case .noValidProviderFound:
                return NSLocalizedString("No valid provider found.", bundle: .module, comment: "noValidProviderFound")
                
            case let .eapConfigurationFailed(error, _):
                return error.errorDescription
                
            case .mobileConfigFailed:
                return NSLocalizedString("No valid profile found.", bundle: .module, comment: "mobileConfigFailed")
                
            case .userCancelled:
                return NSLocalizedString("The configuration process was cancelled.", bundle: .module, comment: "userCancelled")
                
            case let .unknownError(error, _):
                return error.localizedDescription
            }
        }
    }
    
    @Dependency(\.authClient) var authClient
    @Dependency(\.date) var date
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.eapClient) var eapClient
    @Dependency(\.hotspotNetworkClient) var hotspotNetworkClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.urlSession) var urlSession
    
    private func connect(state: inout State, dryRun: Bool) -> Effect<Connect.Action> {
        guard let profile = state.selectedProfile else {
            return .none
        }
        
        guard state.agreedToTerms || state.providerInfo?.termsOfUse?.localized() == nil else {
            let termsAlert = AlertState<Destination.TermsAlertAction>(
                title: {
                    TextState("Terms of Use", bundle: .module)
                }, actions: {
                    ButtonState(action: .send(.agreeButtonTapped)) {
                        TextState("Agree", bundle: .module)
                    }
                    ButtonState(role: .cancel, action: .send(.disagreeButtonTapped)) {
                        TextState("Disagree", bundle: .module)
                    }
                }, message: { [termsOfUse = state.providerInfo?.termsOfUse?.localized()] in
                    var message = NSLocalizedString("You must agree to the terms of use before you can use this network.", bundle: .module, comment: "")
                    if let termsOfUse {
                        message = message + "\n\n" + termsOfUse.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return TextState(message)
                })
            state.destination = .termsAlert(termsAlert)
            return .none
        }
        
        state.loadingState = .isLoading
        let organization = state.organization
        let credentials = state.credentials
        state.credentials = nil
        state.promptForCredentials = false
        let accessToken = state.accessToken
        state.accessToken = nil
        let agreedToTerms = state.agreedToTerms
        return .run { send in
            await send(.connectResponse(TaskResult<ConnectResponse> {
                let (providerInfo, expectedSSIDs, accessToken) = try await connect(organization: organization, profile: profile, authClient: authClient, credentials: credentials, previousAccessToken: accessToken, agreedToTerms: agreedToTerms, dryRun: dryRun)
                let connection: ConnectionType
                if expectedSSIDs.isEmpty {
                    connection = .hotspot20
                } else {
                    connection = .ssids(expectedSSIDs: expectedSSIDs)
                }
                return .init(providerInfo: providerInfo, result: dryRun ? .verified(credentials: credentials, accessToken: accessToken) : .applied(connection))
            }))
        }
    }
    
    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                defer {
                    state.autoConnectOnAppear = false
                }
                guard let _ = state.selectedProfile, (state.organization.hasSingleProfile || state.autoConnectOnAppear) else {
                    return .none
                }
                // Auto connect if there is only a single profile or a reminder was tapped
                return connect(state: &state, dryRun: true)
                
            case let .destination(.presented(.termsAlert(action))):
                switch action {
                case .agreeButtonTapped:
                    state.agreedToTerms = true
                    return connect(state: &state, dryRun: true)
                    
                case .disagreeButtonTapped:
                    state.loadingState = .initial
                    state.agreedToTerms = false
                    return .none
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
                return connect(state: &state, dryRun: true)
                
            case let .connectResponse(.success(connectResponse)):
                switch connectResponse.result {
                case let .verified(credentials, accessToken):
                    // Verified that we should be able to make the connection without errors/prompts, so go ahead and actually setup the network
                    state.providerInfo = connectResponse.providerInfo
                    state.credentials = credentials
                    state.accessToken = accessToken
                    return connect(state: &state, dryRun: false)
                    
                case let .applied(connection):
                    state.providerInfo = connectResponse.providerInfo
                    
                    switch connection {
                    case .hotspot20:
                        state.loadingState = .success(.unknown)
                        return .none
                        
                    case let .ssids(expectedSSIDs: expectedSSIDs):
                        state.loadingState = .success(.disconnected)
                        return .run { send in
                            let currentNetwork = await hotspotNetworkClient.fetchCurrent()
                            if let currentNetwork, expectedSSIDs.contains(currentNetwork.ssid) {
                                await send(.foundSSID(currentNetwork.ssid))
                            }
                        }
                    }
                }
                
            case let .connectResponse(.failure(OrganizationSetupError.missingTermsAcceptance(providerInfo))):
                state.providerInfo = providerInfo
                return connect(state: &state, dryRun: true)
                
            case let .connectResponse(.failure(OrganizationSetupError.eapConfigurationFailed(EAPConfiguratorError.invalidUsername(suffix), providerInfo))):
                state.providerInfo = providerInfo
                state.promptForCredentials = true
                state.requiredUserNameSuffix = suffix
                return .none
                
            case let .connectResponse(.failure(OrganizationSetupError.eapConfigurationFailed(EAPConfiguratorError.missingCredentials(_, requiredSuffix: suffix), providerInfo))):
                state.providerInfo = providerInfo
                state.promptForCredentials = true
                state.requiredUserNameSuffix = suffix
                return .none
                
            case let .connectResponse(.failure(OrganizationSetupError.userCancelled(providerInfo))):
                state.providerInfo = providerInfo
                state.loadingState = .failure
                // Telling the user they cancelled isn't helping
                return .none
                
            case let .connectResponse(.failure(error)):
                // Read providerinfo if error has it so we can populate helpdesk
                state.providerInfo = (error as? OrganizationSetupError)?.providerInfo
                state.loadingState = .failure
                state.requiredUserNameSuffix = nil
                
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
                return connect(state: &state, dryRun: true)
                
            case .foundSSID:
                guard case .success = state.loadingState else {
                    return .none
                }
                state.loadingState = .success(.connected)
                return .none
                
            case .startAgainTapped:
                return .none
                
            case let .updateUsername(username):
                let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
                if let _ = state.credentials {
                    state.credentials?.username = trimmedUsername
                } else {
                    state.credentials = Credentials(username: trimmedUsername)
                }
                return .none
                
            case let .updatePassword(password):
                let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
                if let _ = state.credentials {
                    state.credentials?.password = trimmedPassword
                } else {
                    state.credentials = Credentials(password: trimmedPassword)
                }
                return .none
                
            case .dismissPromptForCredentials:
                state.promptForCredentials = false
                state.requiredUserNameSuffix = nil
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
    
    func connect(organization: Organization, profile: Profile, authClient: AuthClient, credentials: Credentials?, previousAccessToken: String?, agreedToTerms: Bool, dryRun: Bool) async throws -> (ProviderInfo?, [String], String?) {
        let accessToken: String?
        if let previousAccessToken {
            accessToken = previousAccessToken
        } else if profile.oauth ?? false {
            guard let authorizationEndpoint = profile.authorization_endpoint else {
                throw OrganizationSetupError.missingAuthorizationEndpoint
            }
            guard let tokenEndpoint = profile.token_endpoint else {
                throw OrganizationSetupError.missingTokenEndpoint
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
        
        guard let eapConfigURL = profile.eapconfig_endpoint else {
            throw OrganizationSetupError.missingEAPConfigEndpoint
        }
        
        var urlRequest = URLRequest(url: eapConfigURL)
        urlRequest.httpMethod = "POST"
        if let accessToken {
            urlRequest.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
        }

        let (eapConfigData, _) = try await urlSession.data(for: urlRequest)
        
        let providerList = try decoder.decode(EAPIdentityProviderList.self, from: eapConfigData)
        let firstValidProvider = providerList
            .providers
            .first(where: { ($0.validUntil?.timeIntervalSince(date()) ?? 0) >= 0 })
        
        guard let firstValidProvider else {
            throw OrganizationSetupError.noValidProviderFound(providerList.providers.first?.providerInfo)
        }
        
        guard agreedToTerms || firstValidProvider.providerInfo?.termsOfUse?.localized() == nil else {
            throw OrganizationSetupError.missingTermsAcceptance(firstValidProvider.providerInfo)
        }
        
#if os(iOS)
        do {
            let expectedSSIDs = try await eapClient.configure(firstValidProvider, credentials, dryRun)
            
            if !dryRun {
                // Schedule reminder for user to renew network access
                if let validUntil = firstValidProvider.validUntil {
                    let organizationId = organization.id
                    let profileId = profile.id
                    try await notificationClient.scheduleRenewReminder(validUntil, organizationId, profileId)
                }
            }
            
            return (firstValidProvider.providerInfo, expectedSSIDs, accessToken)
            
        } catch let error as EAPConfiguratorError {
            throw OrganizationSetupError.eapConfigurationFailed(error, firstValidProvider.providerInfo)
        } catch {
            let nserror = error as NSError
            switch (nserror.domain, nserror.code) {
            case ("NEHotspotConfigurationErrorDomain", 7):
                throw OrganizationSetupError.userCancelled(firstValidProvider.providerInfo)
            default:
                throw OrganizationSetupError.unknownError(error, firstValidProvider.providerInfo)
            }
        }
#elseif os(macOS)
        do {
            let temporaryDataURL = NSTemporaryDirectory() + "geteduroam.mobileconfig"
           
            defer {
                Task {
                    // Give prefPane a chance to copy file
                    try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                    
                    print("Removing \(temporaryDataURL)")
                    try? FileManager.default.removeItem(atPath: temporaryDataURL)
                }
            }
            
            // FIXME: Replace temporary hack!
            var mobileConfigURLComponents = URLComponents(url: eapConfigURL, resolvingAgainstBaseURL: true)!
            var queryItems = mobileConfigURLComponents.queryItems ?? []
            queryItems.removeAll(where: { item in
                item.name == "device" && item.value == "eap-generic"
            })
            queryItems.append(URLQueryItem(name: "device", value: "apple_global"))
            queryItems.append(URLQueryItem(name: "format", value: "mobileconfig"))
            mobileConfigURLComponents.queryItems = queryItems
            let mobileConfigURL = mobileConfigURLComponents.url!
            var mobileConfigURLRequest = URLRequest(url: mobileConfigURL)
            mobileConfigURLRequest.httpMethod = "POST"
            if let accessToken {
                mobileConfigURLRequest.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
            }
            
            let (data, response) = try await urlSession.data(for: mobileConfigURLRequest)
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(statusCode) else {
                throw OrganizationSetupError.mobileConfigFailed(firstValidProvider.providerInfo)
            }
            try data.write(to: URL(fileURLWithPath: temporaryDataURL))
            
            try Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: ["/System/Library/PreferencePanes/Profiles.prefPane", temporaryDataURL])
            
            // TODO: Get this working on macOS
//            // Check if we are connected to one of the expected SSIDs
//            let expectedSSIDs = ["eduroam"]
//            let connectedSSIDs = try SSID.fetchNetworkInfo().filter( { $0.success == true }).compactMap(\.ssid)
//            print("connectedSSIDs: \(connectedSSIDs)")
//
//            guard connectedSSIDs.first(where: { expectedSSIDs.contains($0) }) != nil else {
//                throw OrganizationSetupError.notConnectedToExpectedSSID(firstValidProvider.providerInfo)
//            }

            // TODO: Get this working on macOS: validUntil unknown, reconnect doesn't trigger navigation in UI
//            // Schedule reminder for user to renew network access
//            let validUntil = Date(timeIntervalSinceNow: 30) // Debug date
//            let organizationId = organization.id
//            let profileId = profile.id
//            try await notificationClient.scheduleRenewReminder(validUntil, organizationId, profileId)

            return (firstValidProvider.providerInfo, [], accessToken)
        } catch {
            throw OrganizationSetupError.unknownError(error, firstValidProvider.providerInfo)
        }
#endif
    }
    
}
