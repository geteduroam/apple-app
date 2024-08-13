import AuthClient
import Backport
import ComposableArchitecture
import Models
import Perception
import SwiftUI

#if os(macOS)
public struct ConnectView_Mac: View {
    public init(store: StoreOf<Connect>) {
        self.store = store
    }
    
    @Perception.Bindable var store: StoreOf<Connect>
    
    @EnvironmentObject var theme: Theme
    
    public var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading) {
                if #available(macOS 13.0, *) {
                    // On macOS 13 we push instead of present a sheet and therefore these controls aren't needed
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) {
                            Text(store.organization.nameOrId)
                                .font(theme.organizationNameFont)
                            Text(store.organization.country)
                                .font(theme.organizationCountryFont)
                        }
                        Spacer()
                        Button(action: {
                            store.send(.dismissTapped)
                        }, label: {
                            Image(systemName: "xmark")
                        })
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                if let providerInfo = store.providerInfo {
                    HelpdeskView(providerInfo: providerInfo)
                    Spacer()
                }
                
                if store.isConfigured == false {
                    List {
                        Section {
                            let selectedProfile = store.selectedProfile
                            ForEach(store.organization.profiles) { profile in
                                Button {
                                    store.send(.select(profile.id))
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
                    .disabled(store.canSelectProfile == false)
                }
                
                Spacer()
                
                if store.isConfigured {
                  HStack(alignment: .top) {
                    Image(systemName: "doc.badge.gearshape.fill")
                    VStack(alignment: .leading) {
                        if #available(macOS 13.0, *) {
                            Text("Continue in System Settings", bundle: .module)
                                .font(theme.connectButtonFont)
                            Text("""
                                Double-click to review the profile and then press the "Install…" button to setup the network on your computer.
                                """, bundle: .module)
                                .font(theme.connectedFont)
                        } else {
                            Text("Continue in System Preferences", bundle: .module)
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
                    
                    Button {
                        store.send(.checkStatusButtonTapped)
                    } label: {
                        Text("Check", bundle: .module)
                    }
                } else {
                    HStack {
                        Spacer()
                        Button {
                            store.send(.connect)
                        } label: {
                            Text("Connect", bundle: .module)
                                .multilineTextAlignment(.center)
                        }
                        .disabled(store.isLoading)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        Spacer()
                    }
                }
            }
            .padding()
            .navigationTitle(store.organization.nameOrId)
            .onAppear {
                store.send(.onAppear)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .alert($store.scope(state: \.destination?.termsAlert, action: \.destination.termsAlert))
            .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
            .alert($store.scope(state: \.destination?.websiteAlert, action: \.destination.websiteAlert))
        }
    }
}
#endif
