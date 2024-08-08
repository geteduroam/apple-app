import AppRemoteConfigClient
import Backport
import ComposableArchitecture
import Connect
import Dependencies
import Models
import Perception
import Status
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct MainView: View {
    public init(store: StoreOf<Main>) {
        self.store = store
    }
    
    @Perception.Bindable public var store: StoreOf<Main>
    
    public var body: some View {
        WithPerceptionTracking {
#if os(iOS)
            MainContentView(store: store)
                .sheet(item: $store.scope(state: \.destination?.connect, action: \.destination.connect)) { store in
                    WithPerceptionTracking {
                        ConnectView(store: store)
                    }
                }
                .sheet(item: $store.scope(state: \.destination?.status, action: \.destination.status)) { store in
                    WithPerceptionTracking {
                        StatusView(store: store)
                    }
                }
#elseif os(macOS)
            if #available(macOS 13.0, *) {
                NavigationStack {
                    // Used instead of `navigationDestination(item:)` because that's broken on macOS 14
                    // With some glue code in the store to derive isConnecting from the current destination this does work
                    MainContentView(store: store)
                        .navigationDestination(isPresented: $store.isConnecting) {
                            if let store = store.scope(state: \.destination?.connect, action: \.destination.connect) {
                                ConnectView(store: store)
                            }
                        }
                }
            } else {
                MainContentView(store: store)
                    .sheet(item: $store.scope(state: \.destination?.connect, action: \.destination.connect)) { store in
                        ConnectView(store: store)
                            .frame(minWidth: 320, minHeight: 480)
                    }
            }
#endif
        }
    }
}
    
struct MainContentView: View {
    public init(store: StoreOf<Main>) {
#if os(iOS)
        // Not exposed via SwiftUI, affects all TextFields…
        UITextField.appearance().clearButtonMode = .whileEditing
#endif
        self.store = store
    }
    
    @Perception.Bindable public var store: StoreOf<Main>
    
    private enum Field: Int, Hashable {
        case search
    }
    
    @FocusState private var focusedField: Field?
    @EnvironmentObject var theme: Theme
    @State var showsFileImporter = false
    @State var showsConfigEditor = false
    @Dependency(\.configClient) var configClient
    
    public var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
#if os(iOS)
                if store.loadingState == .success {
                    VStack(spacing: 8) {
                        HStack {
                            Menu {
                                Button {
                                    showsFileImporter.toggle()
                                } label: {
                                    Label {
                                        Text("Open File…", bundle: .module)
                                    } icon: {
                                        Image(systemName: "doc")
                                    }
                                }
                                if configClient.localValues().showHiddenSettings {
                                    Button {
                                        showsConfigEditor.toggle()
                                    } label: {
                                        Label {
                                            Text("App Configuration…", bundle: .module)
                                        } icon: {
                                            Image(systemName: "questionmark.key.filled")
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                            } primaryAction: {
                                focusedField = .search
                            }
                            .buttonStyle(.plain)
                            TextField(
                                NSLocalizedString("Search for your organization", bundle: .module, comment: "Search prompt"),
                                text: $store.searchQuery)
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
                    if store.loadingState == .success {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                TextField(
                                    NSLocalizedString("Search for your organization", bundle: .module, comment: "Search prompt"),
                                    text: $store.searchQuery)
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
                
                AppStateView()
                
                if store.loadingState == .failure {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Failed to load organizations", bundle: .module)
                            .font(theme.errorFont)
                        Button {
                            store.send(.tryAgainTapped)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .padding(20)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                    
                } else {
                    List {
                        if store.isSearching == false && store.searchQuery.isEmpty == false && store.searchResults.isEmpty {
                            Text("No matches found", bundle: .module)
                                .font(theme.errorFont)
                                .backport
                                .listRowSeparatorTint(Color.clear)
                                .listRowBackground(Color("Background"))
                        } else if store.searchResults.isEmpty {
                            Text(verbatim: "")
                                .accessibility(hidden: true)
                                .backport
                                .listRowSeparatorTint(Color.clear)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(store.searchResults) { organization in
                                Button {
                                    store.send(.select(organization))
                                } label: {
                                    OrganizationRowView(organization: organization)
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
            .searchableMacOnly(text: $store.searchQuery, prompt: NSLocalizedString("Search for your organization", bundle: .module, comment: "Search prompt"))
            .backport
            .simplisticReadableContentWidth()
            .background {
                BackgroundView(showLogo: true)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .onAppear {
                // TODO: To focus or not to focus? searchFieldIsFocused = true
                store.send(.onAppear)
            }
            .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
            .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.eapConfig, .xml]) { result in
                switch result {
                case let .success(scopedURL):
                    store.send(.useLocalFile(scopedURL))
                case .failure:
                    break
                }
            }
            .onOpenURL { url in
                store.send(.useLocalFile(url))
            }
            .onTapGesture(count: 10) {
                #if canImport(UIKit)
                let content = UIPasteboard.general.string
                #elseif canImport(AppKit)
                let content = NSPasteboard.general.string(forType: .string)
                #endif
                if content == "geheim" {
                    configClient.localValues().showHiddenSettings = true
                }
            }
            .sheet(isPresented: $showsConfigEditor) {
                NavigationView {
                    ValuesEditor()
                        .navigationTitle(Text("App Configuration", bundle: .module))
                }
            }
            .disabled(configClient.values().appDisabled)
        }
    }
}

extension View {
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

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(store: .init(initialState: .init(), reducer: { Main() }))
    }
}
#endif
