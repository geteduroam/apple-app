import Backport
import ComposableArchitecture
import Connect
import Models
import SwiftUI

public struct MainView: View {
    public init(store: StoreOf<Main>) {
        #if os(iOS)
        // Not exposed via SwiftUI, affects all TextFields…
        UITextField.appearance().clearButtonMode = .whileEditing
        #endif
        self.store = store
    }
    
    public let store: StoreOf<Main>
    
    private enum Field: Int, Hashable {
        case search
    }
    
    @FocusState private var focusedField: Field?
    @EnvironmentObject var theme: Theme

    struct ViewState: Equatable {
        let loadingState: Main.State.LoadingState
        let isSearching: Bool
        let searchQuery: String
        let searchResults: IdentifiedArrayOf<Institution>
    }
    
    public var body: some View {
        WithViewStore(store, observe: {
            ViewState(
                loadingState: $0.loadingState,
                isSearching: $0.isSearching,
                searchQuery: $0.searchQuery,
                searchResults: $0.searchResults
            )
        }) { viewStore in
            NavigationWrapped {
                VStack(alignment: .leading, spacing: 0) {
#if os(iOS)
                    if viewStore.loadingState == .success {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                TextField(
                                    NSLocalizedString("Search for your institution", bundle: .module, comment: ""),
                                    text: viewStore.binding(get: \.searchQuery, send: Main.Action.searchQueryChanged))
                                .font(theme.searchFont)
                                .focused($focusedField, equals: .search)
                                .backport
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            }
                            Rectangle()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0.33, maxHeight: 0.33)
                                .foregroundColor(Color("ListSeparator"))
                                .padding(.trailing, -20)
                            
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
#endif
                    
                    if #available(macOS 13.0, *) {
                       // Nothing, using .searchable
                    } else {
                        if viewStore.loadingState == .success {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    TextField(
                                        NSLocalizedString("Search for your institution", bundle: .module, comment: ""),
                                        text: viewStore.binding(get: \.searchQuery, send: Main.Action.searchQueryChanged))
                                    .font(theme.searchFont)
                                    .focused($focusedField, equals: .search)
                                    .backport
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                }
                                Rectangle()
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0.33, maxHeight: 0.33)
                                    .foregroundColor(Color("ListSeparator"))
                                    .padding(.trailing, -20)
                                
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                    }
                    
                    if viewStore.loadingState == .failure {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Failed to load institutions", bundle: .module)
                                .font(theme.errorFont)
                            Button {
                                viewStore.send(.tryAgainTapped)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .padding(20)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                        
                    } else {
                        List {
                            if viewStore.isSearching == false && viewStore.searchQuery.isEmpty == false && viewStore.searchResults.isEmpty {
                                Text("No matches found", bundle: .module)
                                    .font(theme.errorFont)
                                    .backport
                                    .listRowSeparatorTint(Color.clear)
                                    .listRowBackground(Color("Background"))
                            } else if viewStore.searchResults.isEmpty {
                                Text("")
                                    .accessibility(hidden: true)
                                    .backport
                                    .listRowSeparatorTint(Color.clear)
                                    .listRowBackground(Color.clear)
                            } else {
                                ForEach(viewStore.searchResults) { institution in
                                    Button {
                                        viewStore.send(.select(institution))
                                    } label: {
                                        InstitutionRowView(institution: institution)
                                    }
                                    .buttonStyle(.plain)
                                    .backport
                                    .listRowSeparatorTint(Color("ListSeparator"))
                                    .listRowBackground(Color("Background"))
                                }
                            }
                        }
                        .listStyle(.plain)
                        .backport
                        .scrollContentBackground(.hidden)
                    }
                }
                .searchableMacOnly(text: viewStore.binding(get: \.searchQuery, send: Main.Action.searchQueryChanged), prompt: NSLocalizedString("Search for your institution", bundle: .module, comment: ""))
                .backport
                .readableContentWidthPadding()
                .background {
                    BackgroundView(showLogo: true)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                .task(id: viewStore.searchQuery) {
                    do {
                        // TODO: Bounce belongs in reducer?
                        try await Task.sleep(nanoseconds: NSEC_PER_SEC / 5)
                        await viewStore.send(.searchQueryChangeDebounced).finish()
                    } catch {}
                }
                .onAppear {
                    // TODO: To focus or not to focus? searchFieldIsFocused = true
                    viewStore.send(.onAppear)
                }
                .connectNavigation(
                    store: store.scope(state: \.$destination, action: Main.Action.destination),
                    state: /Main.Destination.State.connect,
                    action: Main.Destination.Action.connect
                ) {
                    ConnectView(store: $0)
                        .frame(minWidth: 320, minHeight: 480)
                }
                .alert(
                    store: store.scope(state: \.$destination, action: Main.Action.destination),
                    state: /Main.Destination.State.alert,
                    action: Main.Destination.Action.alert
                )
            }
        }
    }
}

extension View {
    func connectNavigation<State, Action, DestinationState, DestinationAction, Content: View>(
        store: Store<PresentationState<State>, PresentationAction<Action>>,
        state toDestinationState: @escaping (State) -> DestinationState?,
        action fromDestinationAction: @escaping (DestinationAction) -> Action,
        @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
    ) -> some View {
#if os(iOS)
        self.sheet(store: store, state: toDestinationState, action: fromDestinationAction, content: content)
#elseif os(macOS)
        if #available(macOS 13.0, *) {
            return AnyView(self.navigationDestination(store: store, state: toDestinationState, action: fromDestinationAction, destination: content))
        } else {
            return AnyView(self.sheet(store: store, state: toDestinationState, action: fromDestinationAction, content: content))
        }
#endif
    }

    // TODO: There is also `backport.searchable`!
    func searchableMacOnly<S>(
        text: Binding<String>,
        prompt: S
    ) -> some View where S : StringProtocol {
#if os(iOS)
        self
#elseif os(macOS)
        if #available(macOS 13.0, *) {
            return self.searchable(text: text, placement: .automatic, prompt: prompt)
        } else {
            return self
        }
#endif
    }
}

struct NavigationWrapped<Content>: View where Content: View {
    @ViewBuilder let content: () -> Content
    
    var body: some View {
#if os(iOS)
        content()
#elseif os(macOS)
        if #available(macOS 13.0, *) {
            NavigationStack {
                content()
            }
        } else {
            content()
        }
#endif
    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(store: .init(initialState: .init(), reducer: Main()))
    }
}
#endif
