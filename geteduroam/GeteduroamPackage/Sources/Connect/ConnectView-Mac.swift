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
                    Text("Continue in System Settings")
                        .font(theme.connectButtonFont)
                    Text("""
                    Double-click to review the profile and then press the "Install…" button to setup the network on your computer.
                    """, bundle: .module)
                    .font(theme.connectedFont)
                    
                    // TODO: Prettify this:
//                    VStack(alignment: .leading) {
//                        InstructionView("Profile downloaded", systemImage: "arrow.down.doc")
//
//                        InstructionView("Continue in System Settings", systemImage: "gear", showsArrow: true)
//
//                        InstructionView("Double-click to review the profile", systemImage: "cursorarrow.click.2")
//
//                        InstructionView("Press the “Install…” button to setup the network", systemImage: "cursorarrow.click")
//
//                        InstructionView("Follow the instructions", systemImage: "checklist")
//                    }
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
            .navigationTitle(viewStore.institution.name)
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

//@available(macOS 13.0, *)
//struct InstructionView: View {
//    internal init(_ text: String, systemImage: String, showsArrow: Bool = false) {
//        self.text = text
//        self.systemImage = systemImage
//        self.showsArrow = showsArrow
//    }
//
//
//    let text: String
//    let systemImage: String
//    let showsArrow: Bool
//
//    let width = 24.0
//
//    var body: some View {
//        HStack {
//            if showsArrow {
//                Image(systemName: "arrow.right")
////                    .resizable()
////                    .aspectRatio(contentMode: .fit)
////                    .frame(height: width)
//            } else {
//
////                Color.clear
////                    .frame(width: width, height: width)
//            }
//            Image(systemName: systemImage)
////                .resizable()
////                .aspectRatio(contentMode: .fit)
////                .frame(height: width)
//            Text(text)
//                .font(.system(.body, design: .default, weight: .bold))
//        }
//    }
//}

//struct ConnectView_Mac_Previews: PreviewProvider {
//    static var previews: some View {
//        ConnectView_Mac(store: .init(
//            initialState: .init(
//                institution: .init(
//                    id: "1",
//                    name: "My Institution",
//                    country: "NL",
//                    cat_idp: 1,
//                    profiles: [
//                        .init(
//                            id: "2",
//                            name: "My Profile",
//                            default: true,
//                            eapconfig_endpoint: nil,
//                            oauth: false,
//                            authorization_endpoint: nil,
//                            token_endpoint: nil),
//                        .init(
//                            id: "3",
//                            name: "Other Profile",
//                            default: false,
//                            eapconfig_endpoint: nil,
//                            oauth: false,
//                            authorization_endpoint: nil,
//                            token_endpoint: nil)
//                    ],
//                    geo: [.init(lat: 0, lon: 0)])),
//            reducer: Connect()))
//        .environmentObject(Theme.demo)
//    }
//}
