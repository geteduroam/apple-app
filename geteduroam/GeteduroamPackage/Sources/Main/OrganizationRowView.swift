import Models
import SwiftUI

public struct OrganizationRowView: View {
    public init(organization: Organization) {
        self.organization = organization
    }
    
    let organization: Organization
    
    @EnvironmentObject var theme: Theme
    
    public var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text(organization.name)
                    .font(theme.organizationNameFont)
                Text(organization.country)
                    .font(theme.organizationCountryFont)
            }
            Spacer()
            Image(systemName: "chevron.right")
        }
        .contentShape(Rectangle())
    }
}

#if DEBUG
struct OrganizationRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            OrganizationRowView(organization: .init(id: "1", name: "My Organization", country: "NL", cat_idp: 1, profiles: [.init(id: "2", name: "My Profile", default: true, eapconfig_endpoint: nil, oauth: false, authorization_endpoint: nil, token_endpoint: nil)], geo: [.init(lat: 0, lon: 0)]))
        }
    }
}
#endif
