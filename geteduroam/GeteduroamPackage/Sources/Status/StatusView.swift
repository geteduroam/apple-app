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
            VStack {
                Spacer()
                
                Group {
                    Text("You have access until \(store.validUntil, format: .dateTime) ") +
                    Text("(\(store.validUntil, format: .relative(presentation: .numeric)))").bold() +
                    Text(".")
                }
                    .font(theme.statusFont)
                
                Spacer()
                Button(action: {
                    store.send(.selectOtherOrganizationButtonTapped)
                }, label: {
                    Text("Select Other Organization", bundle: .module)
                        .multilineTextAlignment(.center)
                })
                .buttonStyle(ConnectButtonStyle())
                
                Button(action: {
                    store.send(.renewButtonTapped)
                }, label: {
                    Text("Renew Connection", bundle: .module)
                        .multilineTextAlignment(.center)
                })
                .buttonStyle(ConnectButtonStyle())
                Spacer()
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .background {
                BackgroundView(showLogo: true, showVersion: false)
            }
            
        }
    }
}
