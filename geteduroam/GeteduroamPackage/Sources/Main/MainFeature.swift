import CacheClient
import ComposableArchitecture
import Connect
import DiscoveryClient
import Foundation
import Models
import NotificationClient

public struct Main: Reducer {
    public init() { }
    
    @Dependency(\.cacheClient) var cacheClient
    @Dependency(\.discoveryClient) var discoveryClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.date.now) var now
    
    public struct State: Equatable {
        public init(searchQuery: String = "", organizations: IdentifiedArrayOf<Organization> = .init(uniqueElements: []), loadingState: LoadingState = .initial, destination: Destination.State? = nil) {
            self.searchQuery = searchQuery
            self.organizations = organizations
            self.loadingState = loadingState
            self.searchResults = .init(uniqueElements: [])
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
        
        @PresentationState public var destination: Destination.State?
    }
    
    public enum Action: Equatable {
        case destination(PresentationAction<Destination.Action>)
        case discoveryResponse(TaskResult<OrganizationsResponse>)
        case onAppear
        case renewActionInReminderTapped(organizationId: String, profileId: String)
        case searchQueryChangeDebounced
        case searchQueryChanged(String)
        case searchResponse(IdentifiedArrayOf<Organization>)
        case select(Organization)
        case tryAgainTapped
    }
    
    public struct Destination: Reducer {
        public enum State: Equatable {
            case connect(Connect.State)
            case alert(AlertState<AlertAction>)
        }
        
        public enum Action: Equatable {
            case connect(Connect.Action)
            case alert(AlertAction)
        }
        
        public enum AlertAction {
            case okButtonTapped
        }
        
        public var body: some Reducer<State, Action>{
            Scope(state: /State.connect, action: /Action.connect) {
                Connect()
            }
        }
    }

    private enum CancelID { case search }

    func search(query: String, organizations: IdentifiedArrayOf<Organization>) async -> IdentifiedArrayOf<Organization> {
        guard query.isEmpty == false else {
            return .init(uniqueElements: [])
        }
        return .init(uniqueElements: organizations
            // Apple recommends this, but that seems to be diacritic sensitive
            // .filter({ $0.name.localizedCaseInsensitiveContains(query) })
            .filter({ $0.matchWords.contains(where: { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .anchored], locale: Locale.current) != nil } )})
            .sorted(by: { $0.name.lowercased() < $1.name.lowercased() }))
    }

    public var body: some Reducer<State, Action> {
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
                                let (value, _) = try await discoveryClient.decodedResponse(for: .discover, as: OrganizationsResponse.self)
                                cacheClient.cacheOrganizations(value)
                                return value
                            } catch {
                                let restoredValue = try cacheClient.restoreOrganizations()
                                return restoredValue
                            }
                        }))
                    })

            case let .discoveryResponse(.success(response)):
                state.loadingState = .success
                state.organizations = .init(uniqueElements: response.instances)
                return .none
                
            case let .discoveryResponse(.failure(error)):
                state.loadingState = .failure
                let alert = AlertState<Destination.AlertAction>(title: {
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
                    let alert = AlertState<Destination.AlertAction>(title: {
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
                
            case let .searchQueryChanged(query):
                state.searchQuery = query
                state.isSearching = true
                
                // When the query is cleared we can clear the search results, but we have to make sure to cancel
                // any in-flight search requests too, otherwise we may get data coming in later.
                guard !query.isEmpty else {
                    state.searchResults = []
                    state.isSearching = false
                    return .cancel(id: CancelID.search)
                }
                return .none
                
            case .searchQueryChangeDebounced:
                guard !state.searchQuery.isEmpty else {
                    return .none
                }
                return .run { [query = state.searchQuery, organizations = state.organizations] send in
                    let searchResults = await self.search(query: query, organizations: organizations)
                    await send(.searchResponse(searchResults))
                }
                .cancellable(id: CancelID.search)
                
            case let .searchResponse(searchResults):
                state.searchResults = searchResults
                state.isSearching = false
                return .none
                
            case let .select(organization):
                state.destination = .connect(.init(organization: organization))
                return .none
                
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
    }
}
