import ComposableArchitecture
import SwiftUI
import Connect
import Models

public struct StatusView: View {
    public init(store: StoreOf<Status>) {
        self.store = store
    }
    
    @Perception.Bindable public var store: StoreOf<Status>
    
    @EnvironmentObject var theme: Theme
    
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
                
                Spacer()
                
                Group {
                    Text("You have access until \(store.validUntil, format: .dateTime) ") +
                    Text("(\(store.validUntil, format: .relative(presentation: .numeric)))").bold() +
                    Text(".")
                }
                .font(theme.statusFont)
                .padding(20)
                
                Spacer()
                if let providerInfo = store.providerInfo {
                    HelpdeskView(providerInfo: providerInfo)
                        .padding(20)
                }
                
                
              
                Spacer()
                
                
                                HStack {
                                    Spacer()
                                    VStack(alignment: .center) {
                                        if store.isConfiguredAndConnected {
                                            Button(action: {
                                                store.send(.selectOtherOrganizationButtonTapped)
                                            }, label: {
                                                Text("Select Other Organization", bundle: .module)
                                                    .multilineTextAlignment(.center)
                                            })
                                            .buttonStyle(ConnectButtonStyle())
//                                            .padding(20)
                                            Button(action: {
                                                store.send(.renewButtonTapped)
                                            }, label: {
                                                Text("Renew Connection", bundle: .module)
                                                    .multilineTextAlignment(.center)
                                            })
                                            .buttonStyle(ConnectButtonStyle())

                                        }
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
//                                            Button {
//                                                store.send(.connect)
//                                            } label: {
//                                                Text("CONNECT", bundle: .module)
//                                                    .multilineTextAlignment(.center)
//                                            }
//                                            .disabled(store.isLoading)
//                                            .buttonStyle(ConnectButtonStyle())
                                            
//                                            Spacer()
//                                            .padding(20)
                                            
                                        }
                                    }
                                    Spacer()
                            }
                            .padding(20)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .background {
                BackgroundView(showLogo: false, showVersion: false)
            }
            
        }
    }
}
