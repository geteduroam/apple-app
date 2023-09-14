import ComposableArchitecture
import DiscoveryClient
import Models
import URLRouting
import XCTest
@testable import Main

@MainActor
final class MainTests: XCTestCase {

    static let eapConfigEndpoint = URL(string: "https://www.example.com/eapconfig")!
    static let letsWifiEndpoint = URL(string: "https://www.example.com/letswifi")!
    
    let demoInstance = Organization(id: "cat_7016", name: ["any": "Môreelsepark Cöllege"], country: "NL", profiles: [Profile(id: "letswifi_cat_7830", name: ["any": "Mijn Moreelsepark"], default: true, letsWiFiEndpoint: MainTests.letsWifiEndpoint, type: .letswifi)], geo: [Coordinate(lat: 52.088999999999999, lon: 5.1130000000000004)])

    func testLoading() async throws {
        let store = TestStore(
            initialState: Main.State(),
            reducer: { Main() },
            withDependencies: {
                $0.discoveryClient = URLRoutingClient<DiscoveryRoute>.failing.override(.discover) {
                    .success((data: 
                    """
                    {
                        "http://letswifi.app/discovery#v2": {
                            "institutions": [
                                {
                                    "id": "cat_7016",
                                    "country": "NL",
                                    "name": {
                                        "any": "Môreelsepark Cöllege"
                                    },
                                    "profiles": [
                                        {
                                            "default": true,
                                            "id": "letswifi_cat_7830",
                                            "letswifi_endpoint": "https://www.example.com/letswifi",
                                            "name": {
                                                "any": "Mijn Moreelsepark"
                                            },
                                            "type": "letswifi"
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
                    }
                    """.data(using: .utf8)!, response: URLResponse()))
                }
                $0.cacheClient.restoreDiscovery = { .init(content: .init(organizations: []))}
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.onAppear) {
            $0.loadingState = .isLoading
        }

        await store.receive(.discoveryResponse(.success(.init(content: .init(organizations: [demoInstance]))))) { [self] in
            $0.loadingState = .success
            $0.organizations = [demoInstance]
        }
    }

    func testSearchByFullname() async throws {
        let store = TestStore(
            initialState: Main.State(organizations: [demoInstance], loadingState: .success),
            reducer: { Main() },
            withDependencies: {
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
            initialState: Main.State(organizations: [demoInstance], loadingState: .success),
            reducer: { Main() },
            withDependencies: {
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
            initialState: Main.State(organizations: [demoInstance], loadingState: .success),
            reducer: { Main() },
            withDependencies: {
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
            initialState: Main.State(organizations: [demoInstance], loadingState: .success),
            reducer: { Main() },
            withDependencies: {
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
            initialState: Main.State(organizations: [demoInstance], loadingState: .success),
            reducer: { Main() },
            withDependencies: {
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
