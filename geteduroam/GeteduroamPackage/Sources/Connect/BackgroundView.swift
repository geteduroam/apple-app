import SwiftUI

public struct BackgroundView: View {
    
    public init(showLogo: Bool) {
        self.showLogo = showLogo
    }
    
    var showLogo: Bool
    
    public var body: some View {
        ZStack {
            Color("Background")
            
            if showLogo {
                VStack(alignment: .trailing) {
                    Spacer()
                    Image("Logo")
                        .resizable()
                        .frame(width: 160, height: 74)
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
