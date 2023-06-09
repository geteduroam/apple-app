import ComposableArchitecture
import DiscoveryClient
import Models
import URLRouting
import XCTest
@testable import Main

@MainActor
final class MainTests: XCTestCase {

    let demoInstance = Institution(id: "cat_7016", name: "Môreelsepark Cöllege", country: "NL", cat_idp: 7016, profiles: [Profile(id: "letswifi_cat_7830", name: "Mijn Moreelsepark", default: true, eapconfig_endpoint: URL(string: "https://moreelsepark.geteduroam.nl/api/eap-config/")!, oauth: true, authorization_endpoint: URL(string: "https://moreelsepark.geteduroam.nl/oauth/authorize/")!, token_endpoint: URL(string: "https://moreelsepark.geteduroam.nl/oauth/token/")!)], geo: [Coordinate(lat: 52.088999999999999, lon: 5.1130000000000004)])

    func testLoading() async throws {
        let store = TestStore(
            initialState: Main.State(),
            reducer: Main(),
            prepareDependencies: {
                $0.discoveryClient = URLRoutingClient<DiscoveryRoute>.failing.override(.discover) {
                    .success((data: """
                    {
                        "instances": [
                            {
                                "id": "cat_7016",
                                "country": "NL",
                                "cat_idp": 7016,
                                "name": "Môreelsepark Cöllege",
                                "profiles": [
                                    {
                                        "default": true,
                                        "authorization_endpoint": "https://moreelsepark.geteduroam.nl/oauth/authorize/",
                                        "oauth": true,
                                        "id": "letswifi_cat_7830",
                                        "eapconfig_endpoint": "https://moreelsepark.geteduroam.nl/api/eap-config/",
                                        "name": "Mijn Moreelsepark",
                                        "token_endpoint": "https://moreelsepark.geteduroam.nl/oauth/token/"
                                    }
                                ],
                                "geo": [
                                    {
                                        "lat": 52.088999999999999,
                                        "lon": 5.1130000000000004
                                    }
                                ]
                            }
                        ]
                    }
                    """.data(using: .utf8)!, response: URLResponse()))
                }
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.onAppear) {
            $0.loadingState = .isLoading
        }

        await store.receive(.discoveryResponse(.success(.init(instances: [demoInstance])))) { [self] in
            $0.loadingState = .success
            $0.institutions = [demoInstance]
        }
    }

    func testSearchByFullname() async throws {
        let store = TestStore(
            initialState: Main.State(institutions: [demoInstance], loadingState: .success),
            reducer: Main(),
            prepareDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.searchQueryChanged("Môreelsepark Cöllege")) {
            $0.isSearching = true
            $0.searchQuery = "Môreelsepark Cöllege"
        }

        await store.send(.searchQueryChangeDebounced)

        await store.receive(.searchResponse(.init(uniqueElements: [demoInstance]))) { [self] in
            $0.isSearching = false
            $0.searchResults = .init(uniqueElements: [demoInstance])
        }
    }

    func testSearchByAbbreviation() async throws {
        let store = TestStore(
            initialState: Main.State(institutions: [demoInstance], loadingState: .success),
            reducer: Main(),
            prepareDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.searchQueryChanged("mc")) {
            $0.isSearching = true
            $0.searchQuery = "mc"
        }

        await store.send(.searchQueryChangeDebounced)

        await store.receive(.searchResponse(.init(uniqueElements: [demoInstance]))) { [self] in
            $0.isSearching = false
            $0.searchResults = .init(uniqueElements: [demoInstance])
        }
    }

    func testSearchCaseInsensitive() async throws {
        let store = TestStore(
            initialState: Main.State(institutions: [demoInstance], loadingState: .success),
            reducer: Main(),
            prepareDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.searchQueryChanged("MOREEL")) {
            $0.isSearching = true
            $0.searchQuery = "MOREEL"
        }

        await store.send(.searchQueryChangeDebounced)

        await store.receive(.searchResponse(.init(uniqueElements: [demoInstance]))) { [self] in
            $0.isSearching = false
            $0.searchResults = .init(uniqueElements: [demoInstance])
        }
    }

    func testSearchDiacriticInsensitive() async throws {
        let store = TestStore(
            initialState: Main.State(institutions: [demoInstance], loadingState: .success),
            reducer: Main(),
            prepareDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.searchQueryChanged("moreel")) {
            $0.isSearching = true
            $0.searchQuery = "moreel"
        }

        await store.send(.searchQueryChangeDebounced)

        await store.receive(.searchResponse(.init(uniqueElements: [demoInstance]))) { [self] in
            $0.isSearching = false
            $0.searchResults = .init(uniqueElements: [demoInstance])
        }
    }

    func testSearchWithPrefixOnly() async throws {
        let store = TestStore(
            initialState: Main.State(institutions: [demoInstance], loadingState: .success),
            reducer: Main(),
            prepareDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.searchQueryChanged("oreelse")) {
            $0.isSearching = true
            $0.searchQuery = "oreelse"
        }

        await store.send(.searchQueryChangeDebounced)

        await store.receive(.searchResponse(.init(uniqueElements: []))) {
            $0.isSearching = false
        }
    }
}
