import ComposableArchitecture

@Reducer
public struct PrivacyPolicy {
    public init() { }
    @ObservableState
    public struct State: Equatable, Sendable {
        public init() { }
    }
    public enum Action: Sendable, Equatable {}
}

