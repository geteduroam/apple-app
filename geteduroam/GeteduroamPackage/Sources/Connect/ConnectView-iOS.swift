#if os(iOS)
import AuthClient
import Backport
import ComposableArchitecture
import Models
import Perception
import SwiftUI

public struct ConnectView_iOS: View {
    public init(store: StoreOf<Connect>) {
        self.store = store
    }
    
    @Perception.Bindable var store: StoreOf<Connect>
    
    @EnvironmentObject var theme: Theme
    
    enum Constants {
        // Closer to the date we show the time as well
        static let detailedDataTimeInterval: TimeInterval = 7 * 24 * 60 * 60
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading) {
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
                .padding(20)
                
                if store.isConfigured {
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
                    
                    if let validUntil = store.validUntil {
                        TimelineView(.explicit([validUntil, validUntil.addingTimeInterval(Constants.detailedDataTimeInterval)])) { context in
                            if context.date.timeIntervalSinceNow <= 0 {
                                Text("You had access until \(context.date, format: .dateTime.day().month().year().hour().minute()) **(\(context.date, format: .relative(presentation: .numeric)))**.", bundle: .module)
                                    .font(theme.statusFont)
                                    .padding(20)
                            } else if context.date.timeIntervalSinceNow >= Constants.detailedDataTimeInterval {
                                Text("You have access until \(context.date, format: .dateTime.day().month().year()) **(\(context.date, format: .relative(presentation: .numeric)))**.", bundle: .module)
                                    .font(theme.statusFont)
                                    .padding(20)
                            } else {
                                Text("You have access until \(context.date, format: .dateTime.day().month().year().hour().minute()) **(\(context.date, format: .relative(presentation: .numeric)))**.", bundle: .module)
                                    .font(theme.statusFont)
                                    .padding(20)
                            }
                        }
                    }
                } else {
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
                if let providerInfo = store.providerInfo {
                    HelpdeskView(providerInfo: providerInfo)
                        .padding(20)
                }
                
                HStack {
                    Spacer()
                    VStack(alignment: .center) {
                        if store.isConfiguredAndConnected {
                            Label(title: {
                                Text("Connected", bundle: .module)
                            }, icon: {
                                Image(systemName: "checkmark.circle")
                            })
                            .font(theme.connectedFont)
                        } else if store.isConfiguredButDisconnected {
                            Label(title: {
                                Text("Configured, but not connected", bundle: .module)
                            }, icon: {
                                Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                            })
                            .font(theme.connectedFont)
                        } else if store.isConfiguredButConnectionUnknown {
                            Label(title: {
                                Text("Configured", bundle: .module)
                            }, icon: {
                                Image(systemName: "checkmark.circle")
                            })
                            .font(theme.connectedFont)
                        } else {
                            Button {
                                store.send(.connect)
                            } label: {
                                Text("CONNECT", bundle: .module)
                                    .multilineTextAlignment(.center)
                            }
                            .disabled(!store.canConnect)
                            .buttonStyle(ConnectButtonStyle())
                        }
                    }
                    
                    if store.canReconnect {
                        Button {
                            store.send(.reconnectTapped)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .accessibilityLabel(Text("Reconnect", bundle: .module))
                                .accentColor(Color("RefreshArrow/Foreground"))
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onDisappear {
                store.send(.onDisappear)
            }
            .background {
                BackgroundView(showLogo: false)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .alert($store.scope(state: \.destination?.termsAlert, action: \.destination.termsAlert))
            .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
            .alert($store.scope(state: \.destination?.websiteAlert, action: \.destination.websiteAlert))
            .backport
            .credentialAlert(
                CredentialAlert(
                    title: NSLocalizedString("Login Required", bundle: .module, comment: ""),
                    isPresented: $store.promptForFullCredentials,
                    usernamePrompt: store.usernamePrompt,
                    username: $store.username,
                    onUsernameSubmit: {
                        store.send(.onUsernameSubmit)
                    },
                    passwordPrompt: NSLocalizedString("Password", bundle: .module, comment: ""),
                    password: $store.password,
                    cancelButtonTitle: NSLocalizedString("Cancel", bundle: .module, comment: ""),
                    cancelAction: {
                        store.promptForFullCredentials = false
                    },
                    doneButtonTitle: NSLocalizedString("Log In", bundle: .module, comment: ""),
                    doneAction: {
                        store.send(.logInButtonTapped)
                    },
                    message: NSLocalizedString("Please enter your username and password.", bundle: .module, comment: "")))
            .backport
            .credentialAlert(
                CredentialAlert(
                    title: NSLocalizedString("Password Required", bundle: .module, comment: ""),
                    isPresented: $store.promptForPasswordOnlyCredentials,
                    passwordPrompt: NSLocalizedString("Password", bundle: .module, comment: ""),
                    password: $store.password,
                    cancelButtonTitle: NSLocalizedString("Cancel", bundle: .module, comment: ""),
                    cancelAction: {
                        store.promptForPasswordOnlyCredentials = false
                    },
                    doneButtonTitle: NSLocalizedString("Log In", bundle: .module, comment: ""),
                    doneAction: {
                        store.send(.logInButtonTapped)
                    },
                    message: NSLocalizedString("Please enter your password.", bundle: .module, comment: "")))
        }
    }
}

#Preview {
    ConnectView_iOS(
        store: .init(
            initialState: .init(
                organization: .init(
                    id: "1",
                    name: [LocalizedEntry(value: "My Organization")],
                    country: "NL",
                    profiles: [
                        Profile(
                            id: "2",
                            name: [LocalizedEntry(value: "My Profile")],
                            default: true,
                            type: .letswifi),
                        Profile(
                            id: "3",
                            name: [LocalizedEntry(value: "Other Profile")],
                            default: false,
                            type: .eapConfig)
                    ]),
                localizedModel: "iPhone"
            ),
            reducer: { Connect()
            })
    )
    .environmentObject(Theme.demo)
}
#endif
