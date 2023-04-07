import SwiftUI
import Models

struct HelpdeskView: View {
    let providerInfo: ProviderInfo
    
    @EnvironmentObject var theme: Theme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let image = providerInfo.providerLogo?.image {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
#if os(iOS)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .accessibility(hidden: true)
                        .padding(8)
#elseif os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .accessibility(hidden: true)
                        .padding(8)
#endif
                }
                .fixedSize()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let name = providerInfo.displayName?.localized() {
                        Text(name)
                            .font(theme.infoHeaderFont)
                            .multilineTextAlignment(.leading)
                    }
                    if let description = providerInfo.description?.localized() {
                        Text(description)
                            .multilineTextAlignment(.leading)
                    }
                }
                if let termsOfUse = providerInfo.termsOfUse?.localized()?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terms Of Use")
                            .font(theme.infoHeaderFont)
                        Text(termsOfUse)
                            .multilineTextAlignment(.leading)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    let helpdesk = providerInfo.helpdesk
                    let webAddress = helpdesk?.webAddress?.localized()
                    let emailAdress = helpdesk?.emailAdress?.localized()
                    let phone = helpdesk?.phone?.localized()
                    if webAddress ?? emailAdress ?? phone != nil {
                        Text("Helpdesk")
                            .font(theme.infoHeaderFont)
                        if let webAddress {
                            Text(attributedString(webAddress))
                        }
                        if let emailAdress {
                            Text(attributedString(emailAdress))
                        }
                        if let phone {
                            Text(attributedString(phone))
                        }
                    }
                }
            }
        }
        .font(theme.infoDetailFont)
        .background(Color("Background"))
    }
    
    private func attributedString(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let fullRange = NSMakeRange(0, text.count)
        // Replacing spaces with dashes to recognize more phone numbers
        let matches = dataDetector.matches(in: text.replacingOccurrences(of: " ", with: "-"), options: [], range: fullRange)
        
        for result in matches {
            guard let range = Range<AttributedString.Index>(result.range, in: attributed) else {
                continue
            }
            
            switch result.resultType {
            case .phoneNumber:
                guard
                    let phoneNumber = result.phoneNumber,
                    let url = URL(string: "tel://\(phoneNumber)")
                else {
                    break
                }
                attributed[range].link = url
#if os(iOS)
                attributed[range].foregroundColor = UIColor(named: "ListSeparator")
#elseif os(macOS)
                attributed[range].foregroundColor = NSColor(named: "ListSeparator")
#endif
            case .link:
                guard let url = result.url else {
                    break
                }
                attributed[range].link = url
#if os(iOS)
                attributed[range].foregroundColor = UIColor(named: "ListSeparator")
#elseif os(macOS)
                attributed[range].foregroundColor = NSColor(named: "ListSeparator")
#endif
                
            default:
                break
            }
        }
        
        return attributed
    }
}

private let dataDetector: NSDataDetector = {
    let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber]
    return try! .init(types: types.rawValue)
}()

#if DEBUG
struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        HelpdeskView(providerInfo: demoProviderInfo)
    }
}
#endif
