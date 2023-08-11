import AuthClient
import Backport
import ComposableArchitecture
import Models
import SwiftUI

#if os(macOS)
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
                if #available(macOS 13.0, *) {
                    // On macOS 13 we push instead of present a sheet and therefor these controls aren't needed
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) {
                            Text(viewStore.organization.name)
                                .font(theme.organizationNameFont)
                            Text(viewStore.organization.country)
                                .font(theme.organizationCountryFont)
                        }
                        Spacer()
                        Button(action: {
                            viewStore.send(.dismissTapped)
                        }, label: {
                            Image(systemName: "xmark")
                        })
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                if let providerInfo = viewStore.providerInfo {
                    HelpdeskView(providerInfo: providerInfo)
                    Spacer()
                }
                
                if viewStore.isConfigured == false {
                    List {
                        Section {
                            let selectedProfile = viewStore.selectedProfile
                            ForEach(viewStore.organization.profiles) { profile in
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
                
                if viewStore.isConfigured {
                  HStack(alignment: .top) {
                    Image(systemName: "doc.badge.gearshape.fill")
                    VStack(alignment: .leading) {
                        if #available(macOS 13.0, *) {
                            Text("Continue in System Settings")
                                .font(theme.connectButtonFont)
                            Text("""
                                Double-click to review the profile and then press the "Install…" button to setup the network on your computer.
                                """, bundle: .module)
                                .font(theme.connectedFont)
                        } else {
                            Text("Continue in System Preferences")
                                .font(theme.connectButtonFont)
                            Text("""
                                Review the profile and then press the "Install…" button to setup the network on your computer.
                                """, bundle: .module)
                                .font(theme.connectedFont)
                        }
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
            .navigationTitle(viewStore.organization.name)
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
#endif
