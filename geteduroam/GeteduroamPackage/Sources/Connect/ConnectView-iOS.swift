#if os(iOS)
import AuthClient
import Backport
import ComposableArchitecture
import Models
import SwiftUI

public struct ConnectView_iOS: View {
    public init(store: StoreOf<Connect>) {
        self.store = store
    }
    
    let store: StoreOf<Connect>
    
    @EnvironmentObject var theme: Theme
    
    // TODO: Define ViewState
    
    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text(viewStore.organization.nameOrId)
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
                .padding(20)
                
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
                if let providerInfo = viewStore.providerInfo {
                    HelpdeskView(providerInfo: providerInfo)
                        .padding(20)
                }
                
                HStack {
                    Spacer()
                    VStack(alignment: .center) {
                        if viewStore.isConfiguredAndConnected {
                            Label(title: {
                                Text("Connected", bundle: .module)
                            }, icon: {
                                Image(systemName: "checkmark.circle")
                            })
                            .font(theme.connectedFont)
                        } else if viewStore.isConfiguredButDisconnected {
                            Label(title: {
                                Text("Configured, but not connected", bundle: .module)
                            }, icon: {
                                Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                            })
                            .font(theme.connectedFont)
                        } else if viewStore.isConfiguredButConnectionUnknown {
                            Label(title: {
                                Text("Configured", bundle: .module)
                            }, icon: {
                                Image(systemName: "checkmark.circle")
                            })
                            .font(theme.connectedFont)
                        } else {
                            Button {
                                viewStore.send(.connect)
                            } label: {
                                Text("CONNECT", bundle: .module)
                                    .multilineTextAlignment(.center)
                            }
                            .disabled(viewStore.isLoading)
                            .buttonStyle(ConnectButtonStyle())
                        }
                    }
                    Spacer()
                }
                .padding(20)
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .background {
                BackgroundView(showLogo: false)
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
            .alert(
                store: store.scope(state: \.$destination, action: Connect.Action.destination),
                state: /Connect.Destination.State.websiteAlert,
                action: Connect.Destination.Action.websiteAlert
            )
            .backport
            .credentialAlert(
                CredentialAlert(
                    title: NSLocalizedString("Login Required", bundle: .module, comment: ""),
                    isPresented: viewStore
                        .binding(
                            get: \.promptForFullCredentials,
                            send: Connect.Action.dismissPromptForCredentials),
                    usernamePrompt: viewStore.usernamePrompt,
                    username: viewStore
                        .binding(
                            get: \.username,
                            send: Connect.Action.updateUsername),
                    onUsernameSubmit: {
                        viewStore.send(.onUsernameSubmit)
                    },
                    passwordPrompt: NSLocalizedString("Password", bundle: .module, comment: ""),
                    password:  viewStore
                        .binding(
                            get: \.password,
                            send: Connect.Action.updatePassword),
                    cancelButtonTitle: NSLocalizedString("Cancel", bundle: .module, comment: ""),
                    cancelAction: {
                        viewStore.send(.dismissPromptForCredentials)
                    },
                    doneButtonTitle: NSLocalizedString("Log In", bundle: .module, comment: ""),
                    doneAction: {
                        viewStore.send(.logInButtonTapped)
                    },
                    message: NSLocalizedString("Please enter your username and password.", bundle: .module, comment: "")))
            .backport
            .credentialAlert(
                CredentialAlert(
                    title: NSLocalizedString("Password Required", bundle: .module, comment: ""),
                    isPresented: viewStore
                        .binding(
                            get: \.promptForPasswordOnlyCredentials,
                            send: Connect.Action.dismissPromptForCredentials),
                    passwordPrompt: NSLocalizedString("Password", bundle: .module, comment: ""),
                    password:  viewStore
                        .binding(
                            get: \.password,
                            send: Connect.Action.updatePassword),
                    cancelButtonTitle: NSLocalizedString("Cancel", bundle: .module, comment: ""),
                    cancelAction: {
                        viewStore.send(.dismissPromptForCredentials)
                    },
                    doneButtonTitle: NSLocalizedString("Log In", bundle: .module, comment: ""),
                    doneAction: {
                        viewStore.send(.logInButtonTapped)
                    },
                    message: NSLocalizedString("Please enter your password.", bundle: .module, comment: "")))
        }
    }
}

#Preview {
    ConnectView_iOS(store: .init(
        initialState: .init(
            organization: .init(
                id: "1",
                name: ["any": "My Organization"],
                country: "NL",
                profiles: [
                    Profile(
                        id: "2",
                        name: ["any": "My Profile"],
                        default: true,
                        type: .letswifi),
                    Profile(
                        id: "3",
                        name: ["any": "Other Profile"],
                        default: false,
                        type: .eapConfig)
                ],
                geo: [Coordinate(lat: 0, lon: 0)])),
        reducer: { Connect() }))
    .environmentObject(Theme.demo)
}
#endif
