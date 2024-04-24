import AppRemoteConfigClient
import Dependencies
import Models
import Perception
import SwiftUI

struct AppStateView: View {
    @Dependency(\.configClient) var configClient
    @EnvironmentObject var theme: Theme
    @State var hideBanner: Bool = false
    
    var showBanner: Bool {
        switch configClient.values().appStateEnum {
        case .active:
            false
        case .updateRecommended, .updateOSRecommended, .obsolete:
            !hideBanner
        case .updateRequired, .updateOSRequired, .disabled:
            true
        }
    }
    
    var systemName: String {
        #if canImport(UIKit)
        UIDevice.current.systemName
        #else
        "macOS"
        #endif
    }
    
    var body: some View {
        WithPerceptionTracking {
            if showBanner {
                Group {
                    HStack(alignment: .firstTextBaseline) {
                        switch configClient.values().appStateEnum {
                        case .active:
                            EmptyView()
                        case .updateRecommended:
                            Text("It is recommended to update this app to the latest version.", bundle: .module)
                        case .updateRequired:
                            Text("It is required to update this app to the latest version.", bundle: .module)
                        case .updateOSRecommended:
                            Text("It is recommended to update \(systemName) to a newer version.", bundle: .module)
                        case .updateOSRequired:
                            Text("It is required to update \(systemName) to a newer version.", bundle: .module)
                        case .obsolete:
                            Text("This app is obsolete.", bundle: .module)
                        case .disabled:
                            Text("This app is disabled.", bundle: .module)
                        }
                        
                        Spacer()
                        
                        switch configClient.values().appStateEnum {
                        case .active, .updateRecommended, .updateOSRecommended, .obsolete:
                            Button(action: {
                                withAnimation {
                                    hideBanner = true
                                }
                            }, label: {
                                Image(systemName: "xmark")
                                    .accessibilityLabel(Text("Close"))
                            })
                            .buttonStyle(.plain)
                        case .updateRequired, .updateOSRequired, .disabled:
                            EmptyView()
                        }
                    }
                }
                .font(theme.infoHeaderFont)
                .padding()
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                .foregroundStyle(Color.white)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 12))
                .padding()
            }
            
            if configClient.values().maintenance {
                Text("This app is under maintenance.", bundle: .module)
                    .font(theme.infoHeaderFont)
                    .padding()
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                    .foregroundStyle(Color.white)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
        }
    }
}
