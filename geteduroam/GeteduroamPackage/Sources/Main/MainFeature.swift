import CacheClient
import ComposableArchitecture
import Connect
import DiscoveryClient
import Foundation
import Models
import NotificationClient
import OSLog

@Reducer
public struct Main: Sendable {
    public init() { }
    
    @Dependency(\.cacheClient) var cacheClient
    @Dependency(\.discoveryClient) var discoveryClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.date.now) var now
    
    public struct PendingRenewAction: Equatable {
        let organizationId: String
        let organizationURLString: String?
        let profileId: String
    }
    
    @ObservableState
    public struct State: Equatable {
        public init(searchQuery: String = "", organizations: IdentifiedArrayOf<Organization> = .init(uniqueElements: []), localizedModel: String, loadingState: LoadingState = .initial, searchResults: IdentifiedArrayOf<Organization> = .init(uniqueElements: []), destination: Destination.State? = nil) {
            self.searchQuery = searchQuery
            self.organizations = organizations
            self.localizedModel = localizedModel
            self.loadingState = loadingState
            self.searchResults = searchResults
            self.destination = destination
        }
        
        public enum LoadingState: Equatable {
            case initial
            case isLoading
            case success
            case failure
        }
        
        var loadingState: LoadingState
        var organizations: IdentifiedArrayOf<Organization>
        let localizedModel: String
        var isSearching: Bool = false
        var searchQuery: String
        var searchResults: IdentifiedArrayOf<Organization>
        fileprivate var pendingRenewAction: PendingRenewAction?
        
        var isConnecting: Bool {
            get {
                switch destination {
                case .connect:
                    return true
                default:
                    return false
                }
            }
            set {
                if newValue == false {
                    destination = nil
                }
            }
        }
        
        @Presents public var destination: Destination.State?
        @Shared(.connection) var configuredConnection = nil
    }
    
    public enum Action: BindableAction {
        case applicationDidFinishLaunching
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case discoveryResponse(TaskResult<DiscoveryResponse>)
        case onAppear
        case renewActionInReminderTapped(organizationId: String, organizationURLString: String?, profileId: String)
        case searchResponse(TaskResult<IdentifiedArrayOf<Organization>>)
        case select(Organization)
        case tryAgainTapped
        case useLocalFile(URL)
        case configuredConnectionFound(ConfiguredConnection)
        case currentConnectionFound(validUntil: Date, organizationId: String, organizationURLString: String?, profileId: String)
        case configuredConnectionUpdated(ConfiguredConnection?)
    }
    
    @Reducer(state: .equatable)
    public enum Destination {
        case connect(Connect)
        case alert(AlertState<AlertAction>)
    }
    
    public enum AlertAction {
        case okButtonTapped
    }

    public enum MainFeatureError: Error, Equatable {
        case searchCancelled
    }
    
    private enum CancelID { case search }

    func search(query: String, organizations: IdentifiedArrayOf<Organization>, configuredOrganization: Organization?) -> IdentifiedArrayOf<Organization> {
        guard query.isEmpty == false else {
            if let configuredOrganization {
                return .init(uniqueElements: [configuredOrganization])
            } else {
                return .init(uniqueElements: [])
            }
        }
        let locale = Locale.current
        let languageCode = locale.languageCode
        let options: String.CompareOptions = query.contains(" ") ? [.caseInsensitive, .diacriticInsensitive] : [.caseInsensitive, .diacriticInsensitive, .anchored]
        return [configuredOrganization].compactMap({ $0 }) + .init(uniqueElements: organizations
            // Apple recommends this, but that seems to be diacritic sensitive
            // .filter({ $0.name.localizedCaseInsensitiveContains(query) })
            .filter({ $0.matchWords(for: languageCode).contains(where: { $0.range(of: query, options: options, locale: locale) != nil } )})
            .sorted(by: { $0.nameOrId.lowercased() < $1.nameOrId.lowercased() }))
            .filter({ $0.id != configuredOrganization?.id })
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            func updateSearchResults() -> IdentifiedArrayOf<Organization> {
                let configuredOrganization: Organization?
                if let configuredOrganizationType = state.configuredConnection?.organizationType {
                    switch configuredOrganizationType {
                    case let .id(id):
                        configuredOrganization = state.organizations[id: id]
                    case let .url(url):
                        configuredOrganization = Organization(query: url)
                    case let .local(url):
                        configuredOrganization = Organization(local: url)
                    }
                } else {
                    configuredOrganization = nil
                }
                return search(query: state.searchQuery, organizations: state.organizations, configuredOrganization: configuredOrganization)
            }
            
            switch action {
            case .applicationDidFinishLaunching:
                Logger.notifications.debug("Application did finish launching")
                let delegate = notificationClient.delegate()
                return .run { send in
                    await withThrowingTaskGroup(of: Void.self) { @MainActor group in
                        group.addTask {
                            for await event in delegate {
                                switch event {
                                case let .renewActionTriggered(organizationId, organizationURLString, profileId):
                                    await send(.renewActionInReminderTapped(organizationId: organizationId, organizationURLString: organizationURLString, profileId: profileId))
                                    
                                case let .remindMeLaterActionTriggered(validUntil, organizationId, organizationURLString, profileId):
                                    guard validUntil.timeIntervalSince(now) > 0 else {
                                        return
                                    }
                                    try await notificationClient.scheduleRenewReminder(validUntil: validUntil, organizationId: organizationId, organizationURLString: organizationURLString, profileId: profileId)
                                }
                            }
                        }
                    }
                }
                
            case .onAppear, .tryAgainTapped:
                state.loadingState = .isLoading
                return .concatenate(
                    .run { send in
                        await send(.discoveryResponse(TaskResult {
                            do {
                                let (value, _) = try await discoveryClient.decodedResponse(for: .discover, as: DiscoveryResponse.self)
                                cacheClient.cacheDiscovery(value)
                                return value
                            } catch {
                                let restoredValue = try cacheClient.restoreDiscovery()
                                return restoredValue
                            }
                        }))
                    },
                    .run { [configuredConnection = state.configuredConnection] send in
                        if let configuredConnection {
                            await send(.configuredConnectionFound(configuredConnection))
                        } else if let (validUntil, organizationId, organizationURLString, profileId) = await notificationClient.scheduledRenewReminder() {
                            await send(.currentConnectionFound(validUntil: validUntil, organizationId: organizationId, organizationURLString: organizationURLString, profileId: profileId))
                        }
                    },
                    .publisher {
                        state.$configuredConnection.publisher
                            .map(Action.configuredConnectionUpdated)
                    }
                )
                
            case let .discoveryResponse(.success(response)):
                state.loadingState = .success
                state.organizations = .init(uniqueElements: response.content.organizations)
                if let pendingRenewAction = state.pendingRenewAction {
                    return .send(.renewActionInReminderTapped(organizationId: pendingRenewAction.organizationId, organizationURLString: pendingRenewAction.organizationURLString, profileId: pendingRenewAction.profileId))
                }
                state.searchResults = updateSearchResults()
                return .none
                
            case let .discoveryResponse(.failure(error)):
                state.loadingState = .failure
                let alert = AlertState<AlertAction>(title: {
                    TextState(NSLocalizedString("Failed to load organizations", bundle: .module, comment: "Message when organizations can't be loaded and the fallback fails too"))
                }, actions: {
                    ButtonState(role: .cancel, action: .send(.okButtonTapped)) {
                        TextState(NSLocalizedString("OK", bundle: .module, comment: ""))
                    }
                }, message: {
                    TextState((error as NSError).localizedDescription)
                })
                state.destination = .alert(alert)
                return .none
                
            case let .renewActionInReminderTapped(organizationId, organizationURLString, profileId):
                switch state.loadingState {
                case .initial, .isLoading:
                    // Perform action when organizations are known
                    state.pendingRenewAction = PendingRenewAction(organizationId: organizationId, organizationURLString: organizationURLString, profileId: profileId)
                    
                case .success, .failure:
                    state.pendingRenewAction = nil
                    
                    if let organization = state.organizations[id: organizationId] {
                        state.destination = .connect(.init(organization: organization, selectedProfileId: profileId, autoConnectOnAppear: true, localizedModel: state.localizedModel))
                    } else if let organizationURLString, let organization = Organization(query: organizationURLString) {
                        state.destination = .connect(.init(organization: organization, selectedProfileId: profileId, autoConnectOnAppear: true, localizedModel: state.localizedModel))
                    } else {
                        let alert = AlertState<AlertAction>(title: {
                            TextState(NSLocalizedString("Unknown organization", bundle: .module, comment: "Title when user asked to renew but the organization could not be found"))
                        }, actions: {
                            ButtonState(role: .cancel, action: .send(.okButtonTapped)) {
                                TextState(NSLocalizedString("OK", bundle: .module, comment: ""))
                            }
                        }, message: {
                            TextState(NSLocalizedString("The organization is no longer listed.", bundle: .module, comment: "Message when user asked to renew but the organization could not be found"))
                        })
                        state.destination = .alert(alert)
                    }
                }
                return .none
                
            case .binding(\.searchQuery):
                let configuredOrganization: Organization?
                if let configuredOrganizationType = state.configuredConnection?.organizationType {
                    switch configuredOrganizationType {
                    case let .id(id):
                        configuredOrganization = state.organizations[id: id]
                    case let .url(url):
                        configuredOrganization = Organization(query: url)
                    case let .local(url):
                        configuredOrganization = Organization(local: url)
                    }
                } else {
                    configuredOrganization = nil
                }
                
                // Clear search without debounce
                guard !state.searchQuery.isEmpty else {
                    if let configuredOrganization {
                        state.searchResults = .init(uniqueElements: [configuredOrganization])
                    } else {
                        state.searchResults = []
                    }
                    state.isSearching = false
                    return .cancel(id: CancelID.search)
                }
                state.isSearching = true
                return .run { [query = state.searchQuery, organizations = state.organizations] send in
                    await send(.searchResponse(
                        TaskResult {
                            // Debounce so user has uninterrupted typing experience
                            try await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
                            if Task.isCancelled {
                                throw MainFeatureError.searchCancelled
                            }
                            var searchResults = search(query: query, organizations: organizations, configuredOrganization: configuredOrganization)
                            if Task.isCancelled {
                                throw MainFeatureError.searchCancelled
                            }
                            
                            // If the query could be an URL, treat it as if it's a Let's Wifi URL
                            if let urlOrganization = Organization(query: query) {
                                searchResults.append(urlOrganization)
                            }
                            return searchResults
                        }
                    ))
                }.cancellable(id: CancelID.search, cancelInFlight: true)
                
            case .binding:
                return .none
                
            case let .searchResponse(.success(searchResults)):
                state.searchResults = searchResults
                state.isSearching = false
                return .none
                
            case .searchResponse(.failure):
                state.isSearching = false
                return .none
                
            case let .select(organization):
                if let configuredConnection = state.configuredConnection, configuredConnection.isConfigured(organization.id, name: organization.nameOrId) {
                    let profileId = configuredConnection.profileId
                    let connectionType = configuredConnection.type
                    let validUntil = configuredConnection.validUntil
                    let providerInfo = configuredConnection.providerInfo
                    state.destination = .connect(.init(organization: organization, selectedProfileId: profileId, localizedModel: state.localizedModel, loadingState: .success(.unknown, connectionType, validUntil: validUntil), providerInfo: providerInfo))
                    return .none
                } else {
                    state.destination = .connect(.init(organization: organization, localizedModel: state.localizedModel))
                    return .none
                }
                
            case .destination:
                return .none
                
            case let .useLocalFile(url):
#if os(iOS)
                let displayName = FileManager().displayName(atPath: url.path)
                let organization = Organization(
                    id: "local",
                    name: [LocalizedEntry(display: displayName)],
                    country: "",
                    profiles: [Profile(id: "local", name: [LocalizedEntry(display: displayName)], default: true, eapConfigEndpoint: url, mobileConfigEndpoint: nil, letsWiFiEndpoint: nil, webviewEndpoint: nil, type: .eapConfig)]
                )
                state.destination = .connect(.init(organization: organization, localizedModel: state.localizedModel))
#else
                NSLog("Opening EAP Config files not supported on macOS/this OS.")
#endif
                return .none
                
            case let .configuredConnectionFound(configuredConnection):
                let organization: Organization?
                switch configuredConnection.organizationType {
                case let .id(organizationId):
                    organization = state.organizations[id: organizationId]
                case let .url(url):
                    organization = Organization(query: url)
                case let .local(url):
                    organization = Organization(local: url)
                }
                guard let organization else {
                    return .none
                }
                let profileId = configuredConnection.profileId
                let connectionType = configuredConnection.type
                let validUntil = configuredConnection.validUntil
                let providerInfo = configuredConnection.providerInfo
                state.destination = .connect(.init(organization: organization, selectedProfileId: profileId, localizedModel: state.localizedModel, loadingState: .success(.unknown, connectionType, validUntil: validUntil), providerInfo: providerInfo))
                
                state.searchResults = updateSearchResults()
                return .none
                
            case let .currentConnectionFound(validUntil, organizationId, organizationURLString, profileId):
                let organization: Organization?
                let organizationType: ConfiguredConnection.OrganizationType?
                if let anOrganization = state.organizations[id: organizationId] {
                    organization = anOrganization
                    organizationType = .id(organizationId)
                } else if let organizationURLString, organizationURLString.hasPrefix("https"), let anOrganization = Organization(query: organizationURLString) {
                    organization = anOrganization
                    organizationType = .url(organizationURLString)
                } else if let organizationURLString, organizationURLString.hasPrefix("file"), let organizationURL = URL(string: organizationURLString) {
                    organization = Organization(local: organizationURL)
                    organizationType = .local(organizationURL)
                } else {
                    organization = nil
                    organizationType = nil
                }
                guard let organization, let organizationType else {
                    return .none
                }
                
                state.configuredConnection = .init(organizationType: organizationType, profileId: profileId, type: nil, validUntil: validUntil, providerInfo: nil)
                state.destination = .connect(.init(organization: organization, selectedProfileId: profileId, localizedModel: state.localizedModel, loadingState: .success(.unknown, nil, validUntil: validUntil), providerInfo: nil))
                
                state.searchResults = updateSearchResults()
                return .none
                
            case .configuredConnectionUpdated:
                state.searchResults = updateSearchResults()
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
