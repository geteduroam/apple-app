#if os(macOS)
import SwiftUI

public struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Privacy Policy")
                    .font(.headline)
                Text("Privacy Policy Content")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 400, minHeight: 300)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Text("Close", bundle: .module)
                }
            }
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
#endif
