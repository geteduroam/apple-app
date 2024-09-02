import Models
import SwiftUI

public struct OrganizationRowView: View {
    public init(organization: Organization, configured: Bool) {
        self.organization = organization
        self.configured = configured
    }
    
    let organization: Organization
    let configured: Bool
    @EnvironmentObject var theme: Theme
    
    public var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text(organization.nameOrId)
                    .font(theme.organizationNameFont)
                Text(organization.country)
                    .font(theme.organizationCountryFont)
            }
            Spacer()
            if configured {
                Image(systemName: "checkmark.circle")
                    .accessibilityValue(Text("Configured", bundle: .module))
            }
            Image(systemName: "chevron.forward")
        }
        .contentShape(Rectangle())
    }
}
