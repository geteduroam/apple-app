import Backport
import ComposableArchitecture
import Connect
import Models
import SwiftUI

public struct MainView: View {
    public init(store: StoreOf<Main>) {
        self.store = store
    }
    
    public let store: StoreOf<Main>
    
    private enum Field: Int, Hashable {
        case search
    }
    
    @FocusState private var focusedField: Field?

    @EnvironmentObject var theme: Theme
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading, spacing: 0) {
                if viewStore.loadingState == .success {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            TextField(
                                NSLocalizedString("Search for your institution", bundle: .module, comment: ""),
                                text: viewStore.binding(get: \.searchQuery, send: Main.Action.searchQueryChanged))
                            .font(theme.searchFont)
                            .focused($focusedField, equals: .search)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            
                            Button {
                                viewStore.send(.searchQueryChanged(""))
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .opacity(focusedField == .search && viewStore.searchQuery.isEmpty == false ? 1 : 0)
                            .accessibility(label: Text("Clear", bundle: .module))
                        }
                        Rectangle()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0.33, maxHeight: 0.33)
                            .foregroundColor(Color("ListSeparator"))
                            .padding(.trailing, -20)
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
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
                                .listRowSeparatorTint(Color.clear)
                                .listRowBackground(Color("Background"))
                        } else if viewStore.searchResults.isEmpty {
                            Text("")
                                .accessibility(hidden: true)
                                .listRowSeparatorTint(Color.clear)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(viewStore.searchResults) { institution in
                                Button {
                                    viewStore.send(.select(institution))
                                } label: {
                                    InstitutionRowView(institution: institution)
                                }
                                .listRowSeparatorTint(Color("ListSeparator"))
                                .listRowBackground(Color("Background"))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .backport
            .readableContentWidthPadding()
            .background {
                ZStack {
                    Color("Background")
                    
                    VStack(alignment: .trailing) {
                        Spacer()
                        Image("Eduroam")
                            .resizable()
                            .frame(width: 160, height: 74)
                            .padding(.bottom, 80)
                        
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .trailing)
                    VStack(spacing: 0) {
                        Image("Heart")
                            .resizable()
                            .frame(width: 200, height: 200)
                            .accessibility(hidden: true)
                        Spacer()
                            .frame(width: 200, height: 200)
                    }
                }
                .edgesIgnoringSafeArea(.all)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .task(id: viewStore.searchQuery) {
                do {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC / 4)
                    await viewStore.send(.searchQueryChangeDebounced).finish()
                } catch {}
            }
            .onAppear {
                // TODO: To focus or not to focus? searchFieldIsFocused = true
                viewStore.send(.onAppear)
            }
            .sheet(isPresented: viewStore.binding(get: \.isSheetVisible, send: Main.Action.dismissSheet)) {
                IfLetStore(store.scope(state: \.selectedInstitutionState, action: Main.Action.institution)) { store in
                    ConnectView(store: store)
                }
            }
            .alert(
                self.store.scope(state: \.alert),
                dismiss: .dismissErrorTapped
            )
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(store: .init(initialState: .init(), reducer: Main()))
    }
}
