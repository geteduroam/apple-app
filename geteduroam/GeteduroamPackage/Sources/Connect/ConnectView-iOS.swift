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
                        Text(viewStore.institution.name)
                            .font(theme.institutionNameFont)
                        Text(viewStore.institution.country)
                            .font(theme.institutionCountryFont)
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
                if let providerInfo = viewStore.providerInfo {
                    HelpdeskView(providerInfo: providerInfo)
                        .padding(20)
                }
                
                HStack {
                    Spacer()
                    VStack(alignment: .center) {
                        if viewStore.isConnected {
                            Label(title: {
                                Text("Connected", bundle: .module)
                            }, icon: {
                                Image(systemName: "checkmark")
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
            .backport
            .credentialAlert(
                CredentialAlert(
                    title: NSLocalizedString("Login Required", comment: ""),
                    isPresented: viewStore
                        .binding(
                            get: \.promptForCredentials,
                            send: Connect.Action.dismissPromptForCredentials),
                    usernamePrompt: viewStore.usernamePrompt,
                    username: viewStore
                        .binding(
                            get: \.username,
                            send: Connect.Action.updateUsername),
                    passwordPrompt: NSLocalizedString("Password", comment: ""),
                    password:  viewStore
                        .binding(
                            get: \.password,
                            send: Connect.Action.updatePassword),
                    cancelButtonTitle: NSLocalizedString("Cancel", comment: ""),
                    cancelAction: {
                        viewStore.send(.dismissPromptForCredentials)
                    },
                    doneButtonTitle: NSLocalizedString("Log In", comment: ""),
                    doneAction: {
                        viewStore.send(.logInButtonTapped)
                    },
                    message: NSLocalizedString("Please enter your username and password.", comment: "")))
        }
    }
}

#if DEBUG
struct ConnectView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectView_iOS(store: .init(
            initialState: .init(
                institution: .init(
                    id: "1",
                    name: "My Institution",
                    country: "NL",
                    cat_idp: 1,
                    profiles: [
                        .init(
                            id: "2",
                            name: "My Profile",
                            default: true,
                            eapconfig_endpoint: nil,
                            oauth: false,
                            authorization_endpoint: nil,
                            token_endpoint: nil),
                        .init(
                            id: "3",
                            name: "Other Profile",
                            default: false,
                            eapconfig_endpoint: nil,
                            oauth: false,
                            authorization_endpoint: nil,
                            token_endpoint: nil)
                    ],
                    geo: [.init(lat: 0, lon: 0)])),
            reducer: Connect()))
        .environmentObject(Theme.demo)
    }
}
#endif
#endif
