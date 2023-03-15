import SwiftUI
import Models

struct HelpdeskView: View {
    let providerInfo: ProviderInfo
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .opacity(0.5)
                Image(systemName: "theatermasks.fill")
                //                    .resizable()
                    .accessibility(hidden: true)
                    .padding(8)
            }
            .fixedSize()
            //            .frame(width: 200, height: 100)
            
            VStack(alignment: .leading) {
                Text(providerInfo.displayName?.localized() ?? "?")
                    .bold()
                Text(providerInfo.description?.localized() ?? "?")
                Spacer()
                Button(action: {
                    
                }, label: {
                    Text("Terms Of Use")
                    Text(providerInfo.termsOfUse?.localized() ?? "?")
                })
                
                
                //            }
                Spacer()
                //            VStack(alignment: .leading) {
                Text("Helpdesk")
                    .bold()
                Button(action: {
                    
                }, label: {
                    Label("www.example.com", systemImage: "info.circle.fill")
                })
                Button(action: {
                    
                }, label: {
                    Label("help@example.com", systemImage: "at.circle.fill")
                })
                Button(action: {
                    
                }, label: {
                    Label("0555-123456", systemImage: "phone.circle.fill")
                })
            }
        }
        .foregroundColor(Color.white)
        Spacer()
    }
}
//
//struct SwiftUIView_Previews: PreviewProvider {
//    static var previews: some View {
//        HelpdeskView()
//            .fixedSize()
//            .background(Color.green)
//    }
//}
