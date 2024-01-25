import SwiftUI
import Models

public struct BackgroundView: View {
    
    @EnvironmentObject var theme: Theme
    
    public init(showLogo: Bool, showVersion: Bool = true) {
        self.showLogo = showLogo
        self.showVersion = showVersion
    }
    
    var showLogo: Bool
    var showVersion: Bool
    
    public var body: some View {
        ZStack {
            Color("Background")
            
            if showLogo {
                VStack(alignment: .trailing) {
                    Spacer()
                    Image("Logo")
                        .resizable()
                        .frame(width: 160, height: 74)
                        .overlay(alignment: .bottomTrailing) {
#if os(iOS)
                            Text(verbatim: AppVersionProvider.appVersion())
                                .font(theme.versionFont)
                                .opacity(0.35)
                                .padding(.trailing, 20)
                                .alignmentGuide(.bottom) { _ in -8 }
#endif
                        }
                        .padding(.bottom, 80)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .trailing)
            }
            
            VStack(spacing: 0) {
                Image("Heart")
                    .resizable()
                    .frame(width: 200, height: 200)
                    .accessibility(hidden: true)
                Spacer()
                    .frame(width: 200, height: 200)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

enum AppVersionProvider {
    static func appVersion(in bundle: Bundle = .main) -> String {
        guard let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            fatalError("CFBundleShortVersionString should not be missing from info dictionary")
        }
        return version
    }
}
