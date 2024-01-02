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
                Text(organization.nameOrId)
                    .font(theme.organizationNameFont)
                Text(organization.country)
                    .font(theme.organizationCountryFont)
            }
            Spacer()
            Image(systemName: "chevron.forward")
        }
        .contentShape(Rectangle())
    }
}
