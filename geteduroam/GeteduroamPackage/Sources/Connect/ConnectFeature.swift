import AppAuth
import AppRemoteConfigClient
import AuthClient
import ComposableArchitecture
import EAPConfigurator
import Foundation
import HotspotNetworkClient
import Models
import NotificationClient
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@preconcurrency import XMLCoder

@Reducer
public struct Connect: Sendable {
    public init() { }
    
    public enum CredentialPromptType {
        case full
        case passwordOnly
    }
    
    @ObservableState
    public struct State: Equatable {
        public init(organization: Organization, selectedProfileId: Profile.ID? = nil, autoConnectOnAppear: Bool = false, localizedModel: String, loadingState: LoadingState = .initial, providerInfo: ProviderInfo? = nil, credentials: Credentials? = nil, destination: Destination.State? = nil) {
            self.organization = organization
            self.selectedProfileId = selectedProfileId
            self.autoConnectOnAppear = autoConnectOnAppear
            self.localizedModel = localizedModel
            self.loadingState = loadingState
            self.providerInfo = providerInfo
            self.credentials = credentials
            self.destination = destination
        }
        
        public let organization: Organization
        public var selectedProfileId: Profile.ID?
        public var autoConnectOnAppear: Bool
        public let localizedModel: String

        public var providerInfo: ProviderInfo?
        public var agreedToTerms: Bool = false
        public var credentials: Credentials?
        public var reusableInfo: ReusableInfo?
        public var requiredUserNameSuffix: String?
        public var userTappedLogIn: Bool = false
        public var promptForCredentials: CredentialPromptType?
        public var promptForFullCredentials: Bool {
            get {
                promptForCredentials == .full
            }
            set {
                if newValue == false {
                    promptForCredentials = nil
                    requiredUserNameSuffix = nil
                    credentials = nil
                    destination = nil
                    loadingState = .initial
                }
            }
        }
        
        public var validUntil: Date? {
            guard case let .success(_, _ , validUntil) = loadingState else {
                return nil
            }
            return validUntil
        }
        
        public var promptForPasswordOnlyCredentials: Bool {
            get {
                promptForCredentials == .passwordOnly
            }
            set {
                if newValue == false {
                    promptForCredentials = nil
                    requiredUserNameSuffix = nil
                    credentials = nil
                    destination = nil
                    loadingState = .initial
                }
            }
        }
        
        public var username: String {
            get {
                credentials?.username ?? ""
            }
            set {
                let trimmedUsername = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let _ = credentials {
                    credentials?.username = trimmedUsername
                } else {
                    credentials = Credentials(username: trimmedUsername)
                }
            }
        }
        
        public var usernamePrompt: String {
            if let requiredUserNameSuffix {
                // Also in right-to-left languages the @suffix bit goes on the right
                return "\u{200E}" + NSLocalizedString("Username", bundle: .module, comment: "") + "@" + requiredUserNameSuffix
            } else {
                return NSLocalizedString("Username", bundle: .module, comment: "")
            }
        }
        
        public mutating func appendRequiredUserNameSuffix() {
            guard let requiredUserNameSuffix, let username = credentials?.username, !username.isEmpty, !username.contains("@") else {
                return
            }
            credentials?.username = username + "@" + requiredUserNameSuffix
        }
        
        public var password: String {
            get {
                credentials?.password ?? ""
            }
            set {
                appendRequiredUserNameSuffix()
                let trimmedPassword = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let _ = credentials {
                    credentials?.password = trimmedPassword
                } else {
                    credentials = Credentials(password: trimmedPassword)
                }
            }
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
            case .isLoading:
                return false
            case .success:
                return true
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
            case let .success(connected, _, _):
                return connected == .connected
            }
        }
        
        public var isConfiguredButConnectionUnknown: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case let .success(connected, _, _):
                return connected == .unknown
            }
        }
        
        public var isConfiguredButDisconnected: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case let .success(connected, _, _):
                return connected == .disconnected
            }
        }
        
        public var canConnect: Bool {
            switch loadingState {
            case .initial, .failure, .success:
                return true
            case .isLoading:
                return false
            }
        }
        
        public var canReconnect: Bool {
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
            case success(ConnectionState, ConnectionType?, validUntil: Date?)
            case failure
        }
        
        var loadingState: LoadingState

        var expectedSSIDs: [String]? {
            switch loadingState {
            case let .success(_, .ssids(expectedSSIDs), _):
                return expectedSSIDs
            default:
                return nil
            }
        }
        
        @Presents public var destination: Destination.State?
        @Shared(.connection) var configuredConnection = nil
    }
    
    public enum ConnectResult: Equatable, Sendable {
        case verified(credentials: Credentials?, reusableInfo: ReusableInfo?)
        case applied(ConnectionType, validUntil: Date?)
    }
    
    public struct ReusableInfo: Equatable, Sendable {
        var accessToken: String?
        var letsWiFiVersion: LetsWiFiVersion?
        var eapConfigData: Data?
    }
    
    public enum ConnectionType: Equatable, Codable, Sendable {
        case ssids(expectedSSIDs: [String])
        case hotspot20
    }
    
    public struct ConnectResponse: Equatable, Sendable {
        public init(providerInfo: ProviderInfo? = nil, result: Connect.ConnectResult) {
            self.providerInfo = providerInfo
            self.result = result
        }
        
        public let providerInfo: ProviderInfo?
        public let result: Connect.ConnectResult
    }
    
    public enum ConnectionState: Codable {
        case unknown
        case disconnected
        case connected
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case connect
        case connectResponse(TaskResult<ConnectResponse>)
        case destination(PresentationAction<Destination.Action>)
        case dismissTapped
        case foundSSID(String)
        case notFoundSSID
        case logInButtonTapped
        case onAppear
        case onDisappear
        case onUsernameSubmit
        case select(Profile.ID)
        case reconnectTapped
    }
    
    @Reducer(state: .equatable, action: .equatable)
    public enum Destination {
        case alert(AlertState<AlertAction>)
        case termsAlert(AlertState<TermsAlertAction>)
        case websiteAlert(AlertState<WebsiteAlertAction>)
    }
    
    public enum AlertAction: Equatable {
        case reconnectButtonTapped
        case switchProfileButtonTapped(Profile.ID)
    }
    
    public enum TermsAlertAction: Equatable {
        case agreeButtonTapped
        case disagreeButtonTapped
    }
    
    public enum WebsiteAlertAction: Equatable {
        case continueButtonTapped(URL)
    }
    
    public enum OrganizationSetupError: Error, LocalizedError, Equatable {
        public static func == (lhs: Connect.OrganizationSetupError, rhs: Connect.OrganizationSetupError) -> Bool {
            (lhs as NSError) == (rhs as NSError)
        }
        
        case eapConfigurationFailed(EAPConfiguratorError, ProviderInfo?)
        case missingAuthorizationEndpoint
        case missingEAPConfigEndpoint
        case missingMobileConfigEndpoint
        case missingProfileType
        case missingTermsAcceptance(ProviderInfo?)
        case missingTokenEndpoint
        case missingOAuthInfo
        case mobileConfigFailed(ProviderInfo?)
        case noValidProviderFound(ProviderInfo?)
        case redirectToWebsite(URL?)
        case unknownError(Error, ProviderInfo?)
        case userCancelled(ProviderInfo?)
        
        var providerInfo: ProviderInfo? {
            switch self {
            case .missingAuthorizationEndpoint, .missingTokenEndpoint, .missingOAuthInfo, .missingEAPConfigEndpoint, .missingProfileType, .missingMobileConfigEndpoint, .redirectToWebsite:
                return nil
            case let .missingTermsAcceptance(info), let .noValidProviderFound(info), let .eapConfigurationFailed(_, info), let .mobileConfigFailed(info), let .userCancelled(info), let .unknownError(_, info):
                return info
            }
        }
 
        public var errorDescription: String? {
            switch self {
            case .missingProfileType:
                return NSLocalizedString("Missing information about profile.", bundle: .module, comment: "missingProfileType")

            case .missingAuthorizationEndpoint:
                return NSLocalizedString("Missing information to start authentication. (auth)", bundle: .module, comment: "missingAuthorizationEndpoint (leave text in brackets out of localization)")
                
            case .missingTokenEndpoint:
                return NSLocalizedString("Missing information to start authentication. (token)", bundle: .module, comment: "missingTokenEndpoint (leave text in brackets out of localization)")
                
            case .missingOAuthInfo:
                return NSLocalizedString("Missing information to start authentication. (info)", bundle: .module, comment: "missingOAuthInfo (leave text in brackets out of localization)")
       
            case .missingEAPConfigEndpoint:
                return NSLocalizedString("Missing information to start configuration. (eap)", bundle: .module, comment: "missingEAPConfigEndpoint (leave text in brackets out of localization)")

            case .missingMobileConfigEndpoint:
                return NSLocalizedString("Missing information to start configuration. (profile)", bundle: .module, comment: "missingMobileConfigEndpoint (leave text in brackets out of localization)")
                
            case .missingTermsAcceptance:
                return NSLocalizedString("You must agree to the terms of use.", bundle: .module, comment: "missingTermsAcceptance (leave text in brackets out of localization)")
                
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
                
            case .redirectToWebsite:
                return nil
            }
        }
    }
    
    @Dependency(\.authClient) var authClient
    @Dependency(\.configClient) var configClient
    @Dependency(\.date) var date
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.eapClient) var eapClient
    @Dependency(\.hotspotNetworkClient) var hotspotNetworkClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.openURL) var openURL
    @Dependency(\.urlSession) var urlSession
    
    private func connect(state: inout State, dryRun: Bool) -> Effect<Connect.Action> {
        guard let profile = state.selectedProfile else {
            return .none
        }
        
        guard state.agreedToTerms || state.providerInfo?.termsOfUse?.localized() == nil else {
            let termsAlert = AlertState<TermsAlertAction>(
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
        state.promptForCredentials = nil
        let reusableInfo = state.reusableInfo
        state.reusableInfo = nil
        let agreedToTerms = state.agreedToTerms
        if !dryRun {
            state.configuredConnection = nil
            notificationClient.unscheduleRenewReminder()
        }
        return .run { send in
            let configValues = await configClient.values()
            let ignoreServerCertificateImportFailureEnabled = await configValues.ignoreServerCertificateImportFailureEnabled
            let ignoreMissingServerCertificateNameEnabled = await configValues.ignoreMissingServerCertificateNameEnabled
            await send(
                .connectResponse(TaskResult<ConnectResponse> {
                    let (providerInfo, expectedSSIDs, validUntil, reusableInfo) = try await connect(
                        organization: organization,
                        profile: profile,
                        authClient: authClient,
                        credentials: credentials,
                        previousReusableInfo: reusableInfo,
                        agreedToTerms: agreedToTerms,
                        dryRun: dryRun,
                        ignoreServerCertificateImportFailureEnabled: ignoreServerCertificateImportFailureEnabled,
                        ignoreMissingServerCertificateNameEnabled: ignoreMissingServerCertificateNameEnabled
                    )
                    let connection: ConnectionType
                    if expectedSSIDs.isEmpty {
                        connection = .hotspot20
                    } else {
                        connection = .ssids(expectedSSIDs: expectedSSIDs)
                    }
                    return .init(providerInfo: providerInfo, result: dryRun ? .verified(credentials: credentials, reusableInfo: reusableInfo) : .applied(connection, validUntil: validUntil))
                })
            )
        }
    }
    
    private enum CancelID { case checkNetwork }
    
    static let checkNetworkRefreshInterval: UInt64 = 3
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action -> Effect<Connect.Action> in
            func checkNetwork(expectedSSIDs: [String]?, afterDelay delay: UInt64? = nil) -> Effect<Connect.Action> {
                .run { send in
                    guard let expectedSSIDs, !expectedSSIDs.isEmpty else {
                        return
                    }
                    if let delay {
                        try await Task.sleep(nanoseconds: NSEC_PER_SEC * delay)
                    }
                    let currentNetwork = await hotspotNetworkClient.fetchCurrent()
                    if let currentNetwork, expectedSSIDs.contains(currentNetwork.ssid) {
                        await send(.foundSSID(currentNetwork.ssid))
                    } else {
                        await send(.notFoundSSID)
                    }
                }
                .cancellable(id: CancelID.checkNetwork, cancelInFlight: true)
            }
            
            switch action {
            case .binding:
                return .none
                
            case .onAppear:
                defer {
                    state.autoConnectOnAppear = false
                }
                if state.isConfigured, let expectedSSIDs = state.expectedSSIDs, expectedSSIDs.isEmpty == false {
                    return checkNetwork(expectedSSIDs: expectedSSIDs)
                }
                guard let _ = state.selectedProfile, (state.organization.hasSingleProfile || state.autoConnectOnAppear) && !state.isConfigured else {
                    return .none
                }
                // Auto connect if there is only a single profile or a reminder was tapped
                return connect(state: &state, dryRun: true)
                
            case .onDisappear:
                return .cancel(id: CancelID.checkNetwork)
                
            case let .destination(.presented(.alert(action))):
                switch action {                    
                case .reconnectButtonTapped:
                    state.configuredConnection = nil
                    notificationClient.unscheduleRenewReminder()
                    state.loadingState = .initial
                    state.credentials = nil
                    state.agreedToTerms = false
                    state.requiredUserNameSuffix = nil
                    state.userTappedLogIn = false
                    state.promptForCredentials = nil
                    return connect(state: &state, dryRun: true)
                    
                case let .switchProfileButtonTapped(profileId):
                    state.configuredConnection = nil
                    notificationClient.unscheduleRenewReminder()
                    state.loadingState = .initial
                    state.credentials = nil
                    state.agreedToTerms = false
                    state.requiredUserNameSuffix = nil
                    state.userTappedLogIn = false
                    state.promptForCredentials = nil
                    state.selectedProfileId = profileId
                    return connect(state: &state, dryRun: true)
                }
                
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
                
            case let .destination(.presented(.websiteAlert(.continueButtonTapped(url)))):
                return .run { _ in
                    await self.openURL(url)
                }
                
            case .destination:
                return .none
                
            case .dismissTapped:
                return .run { _ in
                    await dismiss()
                }
                
            case let .select(profileId):
                if state.isConfigured {
#if os(iOS)
                    guard let currentProfile = state.selectedProfile else {
                        return .none
                    }
                    
                    guard let selectedProfile = state.organization.profiles.first(where: { $0.id == profileId }) else {
                        return .none
                    }
                    
                    guard currentProfile.id != selectedProfile.id else {
                        return .none
                    }
                    
                    let localizedModel = state.localizedModel
                    let alert = AlertState<AlertAction>(
                        title: {
                            TextState("Already configured for \(currentProfile.nameOrId) profile", bundle: .module)
                        }, actions: {
                            ButtonState(role: .destructive, action: .send(.switchProfileButtonTapped(profileId))) {
                                TextState("Reconfigure \(localizedModel)", bundle: .module)
                            }
                            ButtonState(role: .cancel) {
                                TextState("Cancel", bundle: .module)
                            }
                        }, message: {
                            TextState("Do you want to reconfigure your \(localizedModel) to use \(selectedProfile.nameOrId) profile instead?", bundle: .module)
                        })
                    state.destination = .alert(alert)
#endif
                } else {
                    state.selectedProfileId = profileId
                }
                return .none
                
            case .connect:
                return connect(state: &state, dryRun: true)
                
            case let .connectResponse(.success(connectResponse)):
                switch connectResponse.result {
                case let .verified(credentials, reusableInfo):
                    // Verified that we should be able to make the connection without errors/prompts, so go ahead and actually setup the network
                    state.providerInfo = connectResponse.providerInfo
                    state.credentials = credentials
                    state.reusableInfo = reusableInfo
                    return connect(state: &state, dryRun: false)
                    
                case let .applied(connection, validUntil):
                    state.providerInfo = connectResponse.providerInfo
                    
                    if let url = state.selectedProfile?.letsWiFiEndpoint?.absoluteString, state.organization.id == "url" {
                        state.configuredConnection = ConfiguredConnection(organizationType: .url(url), profileId: state.selectedProfile?.id, type: connection, validUntil: validUntil, providerInfo: state.providerInfo)
                    } else if let url = state.selectedProfile?.eapConfigEndpoint, state.organization.id == "local" {
                        state.configuredConnection = ConfiguredConnection(organizationType: .local(url), profileId: state.selectedProfile?.id, type: connection, validUntil: validUntil, providerInfo: state.providerInfo)
                    } else {
                        state.configuredConnection = ConfiguredConnection(organizationType: .id(state.organization.id), profileId: state.selectedProfile?.id, type: connection, validUntil: validUntil, providerInfo: state.providerInfo)
                    }
                    
                    switch connection {
                    case .hotspot20:
                        state.loadingState = .success(.unknown, connection, validUntil: validUntil)
                        return .none
                        
                    case let .ssids(expectedSSIDs: expectedSSIDs):
                        state.loadingState = .success(.disconnected, connection, validUntil: validUntil)
                        return checkNetwork(expectedSSIDs: expectedSSIDs)
                    }
                }
                
            case let .connectResponse(.failure(OrganizationSetupError.missingTermsAcceptance(providerInfo))):
                state.providerInfo = providerInfo
                return connect(state: &state, dryRun: true)
                
            case let .connectResponse(.failure(OrganizationSetupError.eapConfigurationFailed(EAPConfiguratorError.invalidUsername(suffix), providerInfo))):
                state.providerInfo = providerInfo
                state.promptForCredentials = .full
                state.requiredUserNameSuffix = suffix
                if state.userTappedLogIn {
                    if suffix.isEmpty {
                        let alert = AlertState<AlertAction>(
                            title: {
                                TextState("Failed to connect", bundle: .module)
                            }, actions: {
                            }, message: {
                                TextState("You need to provide a valid username.", bundle: .module)
                            })
                        state.destination = .alert(alert)
                        state.userTappedLogIn = false
                    } else {
                        let alert = AlertState<AlertAction>(
                            title: {
                                TextState("Failed to connect", bundle: .module)
                            }, actions: {
                            }, message: {
                                TextState("Your username should end with '@\(suffix)'.", bundle: .module)
                            })
                        state.destination = .alert(alert)
                        state.userTappedLogIn = false
                    }
                }
                return .none
                
            case let .connectResponse(.failure(OrganizationSetupError.eapConfigurationFailed(EAPConfiguratorError.missingCredentials(_, requiredSuffix: suffix), providerInfo))):
                state.providerInfo = providerInfo
                state.promptForCredentials = .full
                state.requiredUserNameSuffix = suffix
                if state.userTappedLogIn {
                    let alert = AlertState<AlertAction>(
                        title: {
                            TextState("Failed to connect", bundle: .module)
                        }, actions: {
                        }, message: {
                            TextState("You need to provide a username and password.", bundle: .module)
                        })
                    state.destination = .alert(alert)
                    state.userTappedLogIn = false
                }
                return .none
                
            case let .connectResponse(.failure(OrganizationSetupError.eapConfigurationFailed(EAPConfiguratorError.missingPassword(_), providerInfo))):
                state.providerInfo = providerInfo
                state.promptForCredentials = .passwordOnly
                if state.userTappedLogIn {
                    let alert = AlertState<AlertAction>(
                        title: {
                            TextState("Failed to connect", bundle: .module)
                        }, actions: {
                        }, message: {
                            TextState("You need to provide a password.", bundle: .module)
                        })
                    state.destination = .alert(alert)
                    state.userTappedLogIn = false
                }
                return .none
                
            case let .connectResponse(.failure(OrganizationSetupError.userCancelled(providerInfo))):
                state.providerInfo = providerInfo
                state.loadingState = .failure
                // Telling the user they cancelled isn't helping
                return .none
                
            case let .connectResponse(.failure(OrganizationSetupError.redirectToWebsite(url))):
                guard let url else {
                    // TODO: Tell user there is no URL?
                    return .none
                }
                let websiteAlert = AlertState<WebsiteAlertAction>(
                    title: {
                        TextState("Continue to Website", bundle: .module)
                    }, actions: {
                        ButtonState(action: .send(.continueButtonTapped(url))) {
                            TextState("Continue", bundle: .module)
                        }
                        ButtonState(role: .cancel) {
                            TextState("Cancel", bundle: .module)
                        }
                    }, message: {
                        let message = NSLocalizedString("You are redirected to a website.", bundle: .module, comment: "") + "\n\n" + url.absoluteString
                        return TextState(message)
                    })
                state.destination = .websiteAlert(websiteAlert)
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
                let alert = AlertState<AlertAction>(
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
                state.userTappedLogIn = true
                return connect(state: &state, dryRun: true)
                
            case .foundSSID:
                guard case let .success(_, type, validUntil) = state.loadingState else {
                    return .none
                }
                state.loadingState = .success(.connected, type, validUntil: validUntil)
                return checkNetwork(expectedSSIDs: state.expectedSSIDs, afterDelay: Self.checkNetworkRefreshInterval)
                
            case .notFoundSSID:
                guard case let .success(_, type, validUntil) = state.loadingState else {
                    return .none
                }
                state.loadingState = .success(.disconnected, type, validUntil: validUntil)
                return checkNetwork(expectedSSIDs: state.expectedSSIDs, afterDelay: Self.checkNetworkRefreshInterval)
                
            case .reconnectTapped:
#if os(iOS)
                guard case let .success(connectionState, _, _) = state.loadingState else {
                    assertionFailure("Reconnect only valid when in success state")
                    return .none
                }
                
                let localizedModel = state.localizedModel
                switch connectionState {
                case .connected:
                    let alert = AlertState<AlertAction>(
                        title: {
                            TextState("Already connected", bundle: .module)
                        }, actions: {
                            ButtonState(role: .destructive, action: .send(.reconnectButtonTapped)) {
                                TextState("Reconfigure \(localizedModel)", bundle: .module)
                            }
                            ButtonState(role: .cancel) {
                                TextState("Cancel", bundle: .module)
                            }
                        }, message: {
                            TextState("Reconfigure your \(localizedModel) to renew your network access or if you are experiencing network issues.", bundle: .module)
                        })
                    state.destination = .alert(alert)
                    
                case .disconnected:
                    let alert = AlertState<AlertAction>(
                        title: {
                            TextState("Already configured, but not connected", bundle: .module)
                        }, actions: {
                            ButtonState(role: .destructive, action: .send(.reconnectButtonTapped)) {
                                TextState("Reconfigure \(localizedModel)", bundle: .module)
                            }
                            ButtonState(role: .cancel) {
                                TextState("Cancel", bundle: .module)
                            }
                        }, message: {
                            TextState("Reconfigure your \(localizedModel) to renew your network access or if you are experiencing network issues.", bundle: .module)
                        })
                    state.destination = .alert(alert)
                    
                case .unknown:
                    let alert = AlertState<AlertAction>(
                        title: {
                            TextState("Already configured", bundle: .module)
                        }, actions: {
                            ButtonState(role: .destructive, action: .send(.reconnectButtonTapped)) {
                                TextState("Reconfigure \(localizedModel)", bundle: .module)
                            }
                            ButtonState(role: .cancel) {
                                TextState("Cancel", bundle: .module)
                            }
                        }, message: {
                            TextState("Reconfigure your \(localizedModel) to renew your network access or if you are experiencing network issues.", bundle: .module)
                        })
                    state.destination = .alert(alert)
                }
                return .none
#else
                assertionFailure()
                return .none
#endif
                
            case .onUsernameSubmit:
                state.appendRequiredUserNameSuffix()
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    var xmlDecoder: XMLDecoder = {
        let decoder = XMLDecoder()
        decoder.shouldProcessNamespaces = true
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    func connect(
        organization: Organization,
        profile: Profile,
        authClient: AuthClient,
        credentials: Credentials?,
        previousReusableInfo: ReusableInfo?,
        agreedToTerms: Bool,
        dryRun: Bool,
        ignoreServerCertificateImportFailureEnabled: IgnoreServerCertificateImportFailureEnabled?,
        ignoreMissingServerCertificateNameEnabled: IgnoreMissingServerCertificateNameEnabled?
    ) async throws -> (ProviderInfo?, [String], Date?, ReusableInfo?) {
        let accessToken: String?
        let eapConfigURL: URL?
        let mobileConfigURL: URL?
        var reusableInfo = ReusableInfo()
        switch profile.type {
        case .none:
            throw OrganizationSetupError.missingProfileType
            
        case .eapConfig:
            accessToken = nil
            eapConfigURL = profile.eapConfigEndpoint
            mobileConfigURL = profile.mobileConfigEndpoint
            
        case .letswifi:
            if let previousReusableInfo, let previousAccessToken = previousReusableInfo.accessToken {
                accessToken = previousAccessToken
                eapConfigURL = previousReusableInfo.letsWiFiVersion?.eapConfigEndpoint
                mobileConfigURL = previousReusableInfo.letsWiFiVersion?.mobileConfigEndpoint
            } else {
                guard let letsWiFiURL = profile.letsWiFiEndpoint else {
                    throw OrganizationSetupError.missingEAPConfigEndpoint
                }
                
                let urlRequest = URLRequest(url: letsWiFiURL)
                
                let (letsWiFiData, _) = try await urlSession.data(for: urlRequest)
                
                let letsWiFi = try jsonDecoder.decode(LetsWiFiResponse.self, from: letsWiFiData)
                reusableInfo.letsWiFiVersion = letsWiFi.content
                
                guard let authorizationEndpoint = letsWiFi.content.authorizationEndpoint else {
                    throw OrganizationSetupError.missingAuthorizationEndpoint
                }
                
                guard let tokenEndpoint = letsWiFi.content.tokenEndpoint else {
                    throw OrganizationSetupError.missingTokenEndpoint
                }
                
                let configuration = OIDServiceConfiguration(authorizationEndpoint: authorizationEndpoint, tokenEndpoint: tokenEndpoint)
                
                // Build authentication request
                guard let clientId = Bundle.main.bundleIdentifier, let redirectURLString = Bundle.main.infoDictionary?["OAuthRedirectURL"] as? String, let redirectURL = URL(string: redirectURLString) else {
                    throw OrganizationSetupError.missingOAuthInfo
                }
                let scope = "eap-metadata"
                let codeVerifier = OIDAuthorizationRequest.generateCodeVerifier()
                let codeChallange = OIDAuthorizationRequest.codeChallengeS256(forVerifier: codeVerifier)
                let state = UUID().uuidString
                let nonce = UUID().uuidString
                
                let request = OIDAuthorizationRequest(configuration: configuration, clientId: clientId, clientSecret: nil, scope: scope, redirectURL: redirectURL, responseType: OIDResponseTypeCode, state: state, nonce: nonce, codeVerifier: codeVerifier, codeChallenge: codeChallange, codeChallengeMethod: OIDOAuthorizationRequestCodeChallengeMethodS256, additionalParameters: nil)
                
                (accessToken, _) = try await authClient
                    .startAuth(request: request)
                    .tokens()
                reusableInfo.accessToken = accessToken
                
                eapConfigURL = letsWiFi.content.eapConfigEndpoint
                mobileConfigURL = letsWiFi.content.mobileConfigEndpoint
            }
        case .webview:
            throw OrganizationSetupError.redirectToWebsite(URL(string: profile.webviewEndpoint ?? ""))
        }
        
#if os(iOS)
        guard let eapConfigURL else {
            throw OrganizationSetupError.missingEAPConfigEndpoint
        }
        
        let eapConfigData: Data
        if eapConfigURL.isFileURL {
            let gotAccess = eapConfigURL.startAccessingSecurityScopedResource()
            defer {
                eapConfigURL.stopAccessingSecurityScopedResource()
            }
            if gotAccess {
                eapConfigData = try Data(contentsOf: eapConfigURL)
            } else {
                // We didn't got access, but we may not even need it, so try anyway
                do {
                    eapConfigData = try Data(contentsOf: eapConfigURL)
                } catch {
                    throw OrganizationSetupError.missingEAPConfigEndpoint
                }
            }
            
        } else {
            var urlRequest = URLRequest(url: eapConfigURL)
            if let accessToken {
                urlRequest.httpMethod = "POST"
                urlRequest.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
            } else {
                urlRequest.httpMethod = "GET"
            }
            
            if let previousEapConfigData = previousReusableInfo?.eapConfigData {
                eapConfigData = previousEapConfigData
            } else {
                (eapConfigData, _) = try await urlSession.data(for: urlRequest)
                reusableInfo.eapConfigData = eapConfigData
            }
        }
        
        let providerList = try xmlDecoder.decode(EAPIdentityProviderList.self, from: eapConfigData)
        let firstValidProvider = providerList
            .providers
            .first(where: { ($0.validUntil?.timeIntervalSince(date()) ?? 0) >= 0 })
        
        guard let firstValidProvider else {
            throw OrganizationSetupError.noValidProviderFound(providerList.providers.first?.providerInfo)
        }
        
        guard agreedToTerms || firstValidProvider.providerInfo?.termsOfUse?.localized() == nil else {
            throw OrganizationSetupError.missingTermsAcceptance(firstValidProvider.providerInfo)
        }

        do {
            let expectedSSIDs = try await eapClient.configure(firstValidProvider, credentials, dryRun, ignoreServerCertificateImportFailureEnabled, ignoreMissingServerCertificateNameEnabled)
            
            let validUntil: Date?
            if !dryRun {
                // Schedule reminder for user to renew network access
                validUntil = firstValidProvider.validUntil
                let organizationURLString: String?
                if let organizationURL = profile.letsWiFiEndpoint?.absoluteString, organization.id == "url" {
                    organizationURLString = organizationURL
                } else if let organizationURL = profile.eapConfigEndpoint?.absoluteString, organization.id == "local" {
                    organizationURLString = organizationURL
                } else {
                    organizationURLString = nil
                }
                if let validUntil {
                    let organizationId = organization.id
                    let profileId = profile.id
                    try await notificationClient.scheduleRenewReminder(validUntil: validUntil, organizationId: organizationId, organizationURLString: organizationURLString, profileId: profileId)
                }
            } else {
                validUntil = nil
            }
            
            return (firstValidProvider.providerInfo, expectedSSIDs, validUntil, reusableInfo)
            
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
        guard let mobileConfigURL else {
            throw OrganizationSetupError.missingMobileConfigEndpoint
        }

        let firstValidProviderInfo: ProviderInfo? = nil
        
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

            var mobileConfigURLRequest = URLRequest(url: mobileConfigURL)
            if let accessToken {
                mobileConfigURLRequest.httpMethod = "POST"
                mobileConfigURLRequest.allHTTPHeaderFields = ["Authorization": "Bearer \(accessToken)"]
            } else {
                mobileConfigURLRequest.httpMethod = "GET"
            }
            
            let (data, response) = try await urlSession.data(for: mobileConfigURLRequest)
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(statusCode) else {
                throw OrganizationSetupError.mobileConfigFailed(firstValidProviderInfo)
            }
            try data.write(to: URL(fileURLWithPath: temporaryDataURL))
            
            try Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: ["/System/Library/PreferencePanes/Profiles.prefPane", temporaryDataURL])

            // TODO: Get this working on macOS: validUntil unknown, reconnect doesn't trigger navigation in UI
//            // Schedule reminder for user to renew network access
//            let validUntil = Date(timeIntervalSinceNow: 30) // Debug date
//            let organizationId = organization.id
//            let profileId = profile.id
//            try await notificationClient.scheduleRenewReminder(validUntil, organizationId, profileId)

            return (firstValidProviderInfo, [], nil, reusableInfo)
        } catch {
            throw OrganizationSetupError.unknownError(error, firstValidProviderInfo)
        }
#endif
    }
    
}
