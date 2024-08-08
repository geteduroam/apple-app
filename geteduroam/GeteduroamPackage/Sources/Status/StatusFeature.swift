import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct Status {
    public init() { }
    
    @ObservableState
    public struct State: Equatable {
        public init(validUntil: Date, organizationId: String, profileId: String) {
            self.validUntil = validUntil
            self.organizationId = organizationId
            self.profileId = profileId
        }
        
        public let validUntil: Date
        public let organizationId: String
        public let profileId: String
    }
    
    public enum Action {
        case selectOtherOrganizationButtonTapped
        case renewButtonTapped
        case delegate(Delegate)
        
        public enum Delegate {
            case renew(organizationId: String, profileId: String)
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .selectOtherOrganizationButtonTapped:
                return .run { _ in
                    await dismiss()
                }
                
            case .renewButtonTapped:
                return .send(.delegate(.renew(organizationId: state.organizationId, profileId: state.profileId)))
                
            case .delegate:
                return .none
            }
        }
    }
}
