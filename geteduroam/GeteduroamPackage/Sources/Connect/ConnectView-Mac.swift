import AuthClient
import Backport
import ComposableArchitecture
import Models
import SwiftUI

public struct ConnectView_Mac: View {
    public init(store: StoreOf<Connect>) {
        self.store = store
    }
    
    let store: StoreOf<Connect>
    
    @EnvironmentObject var theme: Theme
    
    // TODO: Define ViewState
    
    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(alignment: .leading) {
                if let providerInfo = viewStore.providerInfo {
                    HelpdeskView(providerInfo: providerInfo)
                    //                        .padding(20)
                    Spacer()
                }
                
                if viewStore.isConnected == false {
                    List {
                        Section {
                            let selectedProfile = viewStore.selectedProfile
                            ForEach(viewStore.institution.profiles) { profile in
                                Button {
                                    viewStore.send(.select(profile.id))
                                } label: {
                                    ProfileRowView(profile: profile, isSelected: selectedProfile == profile)
                                }
                                .buttonStyle(.plain)
                                .backport
                                .listRowSeparatorTint(Color("ListSeparator"))
                                .listRowBackground(Color("Background"))
                            }
                        } header: {
                            Text("Profiles", bundle: .module)
                                .font(theme.profilesHeaderFont)
                        }
                    }
                    .listStyle(.plain)
                    .disabled(viewStore.canSelectProfile == false)
                }
                
                Spacer()
                
                if viewStore.isConnected {
                  HStack(alignment: .top) {
                    Image(systemName: "doc.badge.gearshape.fill")
                    VStack(alignment: .leading) {
                      Text("Continue in System Settings")
                        .font(theme.connectButtonFont)
                      Text("""
                    Double-click to review the profile and then press the "Install…" button to setup the network on your computer.
                    """, bundle: .module)
                      .font(theme.connectedFont)
                    }
                  }
                  .foregroundColor(.black)
                  .padding()
                  .background(Color.accentColor)
                  .cornerRadius(6)
                } else {
                    HStack {
                        Spacer()
                        Button {
                            viewStore.send(.connect)
                        } label: {
                            Text("Connect", bundle: .module)
                                .multilineTextAlignment(.center)
                        }
                        .disabled(viewStore.isLoading)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        Spacer()
                    }
                }
            }
            .padding()
            .navigationTitle(viewStore.institution.nameOrId)
            .onAppear {
                viewStore.send(.onAppear)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .alert(
                store: store.scope(state: \.$destination, action: Connect.Action.destination),
                state: /Connect.Destination.State.termsAlert,
                action: Connect.Destination.Action.termsAlert
            )
            .alert(
                store: store.scope(state: \.$destination, action: Connect.Action.destination),
                state: /Connect.Destination.State.alert,
                action: Connect.Destination.Action.alert
            )
        }
    }
}

struct ConnectView_Mac_Previews: PreviewProvider {
    static var previews: some View {
        ConnectView_Mac(store: .init(
            initialState: .init(
                institution: .init(
                    id: "1",
                    name: "My Institution",
                    country: "NL",
                    profiles: [
                        .init(
                            id: "2",
                            name: "My Profile",
                            default: true),
                        .init(
                            id: "3",
                            name: "Other Profile")
                    ],
                    geo: [.init(lat: 0, lon: 0)])),
            reducer: Connect()))
        .environmentObject(Theme.demo)
    }
}
