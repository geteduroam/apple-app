import Models
import SwiftUI

struct ProfileRowView: View {
    let profile: Profile
    let isSelected: Bool
    
    @EnvironmentObject var theme: Theme
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(profile.nameOrId)
                    .font(theme.profileNameFont)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileRowView(profile: .init(id: "profile1", name: [LocalizedEntry(display: "My Profile")]), isSelected: true)
}

#Preview {
    ProfileRowView(profile: .init(id: "profile2", name: [LocalizedEntry(display: "My Other Profile")]), isSelected: false)
}
