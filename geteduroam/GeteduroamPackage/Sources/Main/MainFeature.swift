import CacheClient
import ComposableArchitecture
import Connect
import DiscoveryClient
import Foundation
import Models
import NotificationClient

@Reducer
public struct Main: Reducer {
    public init() { }
    
    @Dependency(\.cacheClient) var cacheClient
    @Dependency(\.discoveryClient) var discoveryClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.date.now) var now
    
    @ObservableState
    public struct State: Equatable {
        public init(searchQuery: String = "", organizations: IdentifiedArrayOf<Organization> = .init(uniqueElements: []), loadingState: LoadingState = .initial, searchResults: IdentifiedArrayOf<Organization> = .init(uniqueElements: []), destination: Destination.State? = nil) {
            self.searchQuery = searchQuery
            self.organizations = organizations
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
        var isSearching: Bool = false
        var searchQuery: String
        var searchResults: IdentifiedArrayOf<Organization>
        
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
    }
    
    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case discoveryResponse(TaskResult<DiscoveryResponse>)
        case onAppear
        case renewActionInReminderTapped(organizationId: String, profileId: String)
        case searchResponse(TaskResult<IdentifiedArrayOf<Organization>>)
        case select(Organization)
        case tryAgainTapped
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

    func search(query: String, organizations: IdentifiedArrayOf<Organization>) async -> IdentifiedArrayOf<Organization> {
        guard query.isEmpty == false else {
            return .init(uniqueElements: [])
        }
        let locale = Locale.current
        let languageCode = locale.languageCode
        return .init(uniqueElements: organizations
            // Apple recommends this, but that seems to be diacritic sensitive
            // .filter({ $0.name.localizedCaseInsensitiveContains(query) })
            .filter({ $0.matchWords(for: languageCode).contains(where: { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .anchored], locale: locale) != nil } )})
            .sorted(by: { $0.nameOrId.lowercased() < $1.nameOrId.lowercased() }))
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear, .tryAgainTapped:
                state.loadingState = .isLoading
                return .merge(
                    .run { send in
                        for await event in notificationClient.delegate() {
                            switch event {
                            case .renewActionTriggered(organizationId: let organizationId, profileId: let profileId):
                                await send(.renewActionInReminderTapped(organizationId: organizationId, profileId: profileId))
                                
                            case let .remindMeLaterActionTriggered(validUntil, organizationId, profileId):
                                guard validUntil.timeIntervalSince(now) > 0 else {
                                    return
                                }
                                try await notificationClient.scheduleRenewReminder(validUntil, organizationId, profileId)
                            }
                        }
                    },
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
                    })

            case let .discoveryResponse(.success(response)):
                state.loadingState = .success
                state.organizations = .init(uniqueElements: response.content.organizations)
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
                
            case let .renewActionInReminderTapped(organizationId, profile):
                if let organization = state.organizations[id: organizationId] {
                    state.destination = .connect(.init(organization: organization, selectedProfileId: profile, autoConnectOnAppear: true))
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
                return .none
                
            case .binding(\.searchQuery):
                // Clear search without debounce
                guard !state.searchQuery.isEmpty else {
                    state.searchResults = []
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
                            let searchResults = await self.search(query: query, organizations: organizations)
                            if Task.isCancelled {
                                throw MainFeatureError.searchCancelled
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
                state.destination = .connect(.init(organization: organization))
                return .none
                
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
