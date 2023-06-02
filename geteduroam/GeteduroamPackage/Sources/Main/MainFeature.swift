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
        public init(searchQuery: String = "", institutions: IdentifiedArrayOf<Institution> = .init(uniqueElements: []), loadingState: LoadingState = .initial, destination: Destination.State? = nil) {
            self.searchQuery = searchQuery
            self.institutions = institutions
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
        var institutions: IdentifiedArrayOf<Institution>
        var isSearching: Bool = false
        var searchQuery: String
        var searchResults: IdentifiedArrayOf<Institution>
        
        @PresentationState public var destination: Destination.State?
    }
    
    public enum Action: Equatable {
        case destination(PresentationAction<Destination.Action>)
        case discoveryResponse(TaskResult<InstitutionsResponse>)
        case onAppear
        case renewActionInReminderTapped(institutionId: String, profileId: String)
        case searchQueryChangeDebounced
        case searchQueryChanged(String)
        case searchResponse(IdentifiedArrayOf<Institution>)
        case select(Institution)
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

    func search(query: String, institutions: IdentifiedArrayOf<Institution>) async -> IdentifiedArrayOf<Institution> {
        guard query.isEmpty == false else {
            return .init(uniqueElements: [])
        }
        return .init(uniqueElements: institutions
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
                            case .renewActionTriggered(institutionId: let institutionId, profileId: let profileId):
                                await send(.renewActionInReminderTapped(institutionId: institutionId, profileId: profileId))
                                
                            case let .remindMeLaterActionTriggered(validUntil, institutionId, profileId):
                                guard validUntil.timeIntervalSince(now) > 0 else {
                                    return
                                }
                                try await notificationClient.scheduleRenewReminder(validUntil, institutionId, profileId)
                            }
                        }
                    },
                    .task {
                        await .discoveryResponse(TaskResult {
                            do {
                                let (value, _) = try await discoveryClient.decodedResponse(for: .discover, as: InstitutionsResponse.self)
                                cacheClient.cacheInstitutions(value)
                                return value
                            } catch {
                                let restoredValue = try cacheClient.restoreInstitutions()
                                return restoredValue
                            }
                        })
                    })

            case let .discoveryResponse(.success(response)):
                state.loadingState = .success
                state.institutions = .init(uniqueElements: response.instances)
                return .none
                
            case let .discoveryResponse(.failure(error)):
                state.loadingState = .failure
                let alert = AlertState<Destination.AlertAction>(title: {
                    TextState(NSLocalizedString("Failed to load institutions", bundle: .module, comment: ""))
                }, actions: {
                    ButtonState(role: .cancel, action: .send(.okButtonTapped)) {
                        TextState(NSLocalizedString("OK", bundle: .module, comment: ""))
                    }
                }, message: {
                    TextState((error as NSError).localizedDescription)
                })
                state.destination = .alert(alert)
                return .none
                
            case let .renewActionInReminderTapped(institutionId, profile):
                if let institution = state.institutions[id: institutionId] {
                    state.destination = .connect(.init(institution: institution, selectedProfileId: profile, autoConnectOnAppear: true))
                } else {
                    let alert = AlertState<Destination.AlertAction>(title: {
                        TextState(NSLocalizedString("Unknown institution", bundle: .module, comment: ""))
                    }, actions: {
                        ButtonState(role: .cancel, action: .send(.okButtonTapped)) {
                            TextState(NSLocalizedString("OK", bundle: .module, comment: ""))
                        }
                    }, message: {
                        TextState(NSLocalizedString("The institution is no longer listed.", bundle: .module, comment: ""))
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
                return .task { [query = state.searchQuery, institutions = state.institutions] in
                    let searchResults = await self.search(query: query, institutions: institutions)
                    return .searchResponse(searchResults)
                }
                .cancellable(id: CancelID.search)
                
            case let .searchResponse(searchResults):
                state.searchResults = searchResults
                state.isSearching = false
                return .none
                
            case let .select(institution):
                state.destination = .connect(.init(institution: institution))
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
