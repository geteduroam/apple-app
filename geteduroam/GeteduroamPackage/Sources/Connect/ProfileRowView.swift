import Models
import SwiftUI

struct ProfileRowView: View {
    let profile: Profile
    let isSelected: Bool
    
    @EnvironmentObject var theme: Theme
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(profile.name)
                    .font(theme.profileNameFont)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

struct ProfileRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ProfileRowView(profile: .init(id: "profile1", name: "My Profile"), isSelected: true)
            ProfileRowView(profile: .init(id: "profile2", name: "My Other Profile"), isSelected: false)
        }
    }
}
