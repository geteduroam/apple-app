import ComposableArchitecture

@Reducer
public struct PrivacyPolicy {
    @ObservableState
    public struct State: Equatable, Sendable {}
    public enum Action: Sendable {}
}
