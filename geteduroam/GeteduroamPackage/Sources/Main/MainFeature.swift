import AuthClient
import CacheClient
import ComposableArchitecture
import Connect
import DiscoveryClient
import Foundation
import Models

public struct Main: Reducer {
    public let authClient: AuthClient
    @Dependency(\.cacheClient) var cacheClient
    @Dependency(\.discoveryClient) var discoveryClient
    
    public init(authClient: AuthClient = FailingAuthClient()) {
        self.authClient = authClient
    }
    
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
        case searchQueryChangeDebounced
        case searchQueryChanged(String)
        case searchResponse(TaskResult<IdentifiedArrayOf<Institution>>)
        case select(Institution)
        case tryAgainTapped
        
        public enum Alert: Equatable {
            case okButtonTapped
        }
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
    
    private enum SearchID {}
    
    func search(query: String, institutions: IdentifiedArrayOf<Institution>) -> IdentifiedArrayOf<Institution> {
        guard query.isEmpty == false else {
            return .init(uniqueElements: [])
        }
        return .init(uniqueElements: institutions
            // Apple recommends this, but that seems to be diacritic sensitive
            // .filter({ $0.name.localizedCaseInsensitiveContains(query) })
            .filter({ $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale.current) != nil })
            .sorted(by: { $0.name < $1.name }))
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear, .tryAgainTapped:
                state.loadingState = .isLoading
                return .task {
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
                }

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
                
            case let .searchQueryChanged(query):
                state.searchQuery = query
                state.isSearching = true
                
                // When the query is cleared we can clear the search results, but we have to make sure to cancel
                // any in-flight search requests too, otherwise we may get data coming in later.
                guard !query.isEmpty else {
                    state.searchResults = []
                    state.isSearching = false
                    return .cancel(id: SearchID.self)
                }
                return .none
                
            case .searchQueryChangeDebounced:
                guard !state.searchQuery.isEmpty else {
                    return .none
                }
                return .task { [query = state.searchQuery, institutions = state.institutions] in
                    await .searchResponse(TaskResult { self.search(query: query, institutions: institutions) })
                }
                .cancellable(id: SearchID.self)
                
            case let .searchResponse(.success(searchResults)):
                state.searchResults = searchResults
                state.isSearching = false
                return .none
                
            case .searchResponse(.failure):
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
