import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct Status {
    public init() { }
    
    @ObservableState
    public struct State: Equatable {
        public init(validUntil: Date, organization: Organization, organizationId: String, profileId: String, providerInfo: ProviderInfo?) {
            self.validUntil = validUntil
            self.organization = organization
            self.organizationId = organizationId
            self.profileId = profileId
            self.providerInfo = providerInfo
            self.loadingState = .success(.unknown)
        }
        
        public let validUntil: Date
        public let organization: Organization
        public let organizationId: String
        public let profileId: String
        public let providerInfo: ProviderInfo?
        
        public var isConfiguredAndConnected: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case let .success(connected):
                return connected == .connected
            }
        }
        
        public var isConfiguredButConnectionUnknown: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case let .success(connected):
                return connected == .unknown
            }
        }
        
        public var isConfiguredButDisconnected: Bool {
            switch loadingState {
            case .initial, .failure, .isLoading:
                return false
            case let .success(connected):
                return connected == .disconnected
            }
        }
        
        
        public enum ConnectionState {
            case unknown
            case disconnected
            case connected
        }
        
        public enum LoadingState: Equatable {
            case initial
            case isLoading
            case success(ConnectionState)
            case failure
        }
        
        var loadingState: LoadingState
    }
    
    public enum Action {
        case selectOtherOrganizationButtonTapped
        case renewButtonTapped
        case dismissTapped
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
                
            case .dismissTapped:
                return .run { _ in
                    await dismiss()
                }
                
            case .delegate:
                return .none
            }
        }
    }
}
