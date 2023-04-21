import ComposableArchitecture
import Models
import SwiftUI

public struct ConnectView: View {
    public init(store: StoreOf<Connect>) {
        self.store = store
    }
    
    let store: StoreOf<Connect>
    
#if os(iOS)
    public var body: some View {
        ConnectView_iOS(store: store)
    }
#elseif os(macOS)
    public var body: some View {
        ConnectView_Mac(store: store)
    }
#endif
}
