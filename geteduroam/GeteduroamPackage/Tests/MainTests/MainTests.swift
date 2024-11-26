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
    
    let demoInstance = Organization(id: "cat_7016", name: [LocalizedEntry(language: nil, value: "Môreelsepark Cöllege")], country: "NL", profiles: [Profile(id: "letswifi_cat_7830", name: [LocalizedEntry(language: nil, value: "Mijn Moreelsepark")], default: true, letsWiFiEndpoint: MainTests.letsWifiEndpoint, type: .letswifi)])

    func testLoading() async throws {
        let store = TestStore(
            initialState: Main.State(localizedModel: "test model"),
            reducer: { Main() },
            withDependencies: {
                $0.discoveryClient = URLRoutingClient<DiscoveryRoute>.failing.override(.discover) {
                    .success((data: 
                    """
                    {
                        "http://letswifi.app/discovery#v3": {
                            "providers": [
                                {
                                    "id": "cat_7016",
                                    "country": "NL",
                                    "name": [
                                        {
                                            "": "Môreelsepark Cöllege"
                                        }
                                    ],
                                    "profiles": [
                                        {
                                            "default": true,
                                            "id": "letswifi_cat_7830",
                                            "letswifi_endpoint": "https://www.example.com/letswifi",
                                            "name": [
                                                {
                                                    "": "Mijn Moreelsepark"
                                                }
                                            ],
                                            "type": "letswifi"
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
                $0.notificationClient.scheduledRenewReminder = { nil }
            })

        await store.send(.onAppear) {
            $0.loadingState = .isLoading
        }

        await store.receive(\.discoveryResponse) { [self] in
            $0.loadingState = .success
            $0.organizations = [demoInstance]
        }
        
        await store.skipInFlightEffects()
    }

    func testSearchByFullname() async throws {
        let store = TestStore(
            initialState: Main.State(organizations: [demoInstance], localizedModel: "test model", loadingState: .success),
            reducer: { Main() },
            withDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.binding(.set(\.searchQuery, "Môreelsepark Cöllege"))) {
            $0.isSearching = true
            $0.searchQuery = "Môreelsepark Cöllege"
        }

        await store.receive(\.searchResponse, timeout: NSEC_PER_SEC) { [self] in
            $0.isSearching = false
            $0.searchResults = .init(uniqueElements: [demoInstance])
        }
    }

    func testSearchByAbbreviation() async throws {
        let store = TestStore(
            initialState: Main.State(organizations: [demoInstance], localizedModel: "test model", loadingState: .success),
            reducer: { Main() },
            withDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.binding(.set(\.searchQuery, "mc"))) {
            $0.isSearching = true
            $0.searchQuery = "mc"
        }

        await store.receive(\.searchResponse, timeout: NSEC_PER_SEC) { [self] in
            $0.isSearching = false
            $0.searchResults = .init(uniqueElements: [demoInstance])
        }
    }

    func testSearchCaseInsensitive() async throws {
        let store = TestStore(
            initialState: Main.State(organizations: [demoInstance], localizedModel: "test model", loadingState: .success),
            reducer: { Main() },
            withDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.binding(.set(\.searchQuery, "MOREEL"))) {
            $0.isSearching = true
            $0.searchQuery = "MOREEL"
        }

        await store.receive(\.searchResponse, timeout: NSEC_PER_SEC) { [self] in
            $0.isSearching = false
            $0.searchResults = .init(uniqueElements: [demoInstance])
        }
    }

    func testSearchDiacriticInsensitive() async throws {
        let store = TestStore(
            initialState: Main.State(organizations: [demoInstance], localizedModel: "test model", loadingState: .success),
            reducer: { Main() },
            withDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.binding(.set(\.searchQuery, "moreel"))) {
            $0.isSearching = true
            $0.searchQuery = "moreel"
        }

        await store.receive(\.searchResponse, timeout: NSEC_PER_SEC) { [self] in
            $0.isSearching = false
            $0.searchResults = .init(uniqueElements: [demoInstance])
        }
    }

    func testSearchWithPrefixOnly() async throws {
        let store = TestStore(
            initialState: Main.State(organizations: [demoInstance], localizedModel: "test model", loadingState: .success),
            reducer: { Main() },
            withDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.binding(.set(\.searchQuery, "oreelse"))) {
            $0.isSearching = true
            $0.searchQuery = "oreelse"
        }

        await store.receive(\.searchResponse, timeout: NSEC_PER_SEC) {
            $0.isSearching = false
        }
    }
    
    func testSearchWithURL() async throws {
        let store = TestStore(
            initialState: Main.State(organizations: [demoInstance], localizedModel: "test model", loadingState: .success),
            reducer: { Main() },
            withDependencies: {
                $0.notificationClient.delegate = { .finished }
            })

        await store.send(.binding(.set(\.searchQuery, "geteduroam.nl"))) {
            $0.isSearching = true
            $0.searchQuery = "geteduroam.nl"
        }

        await store.receive(\.searchResponse, timeout: NSEC_PER_SEC) {
            $0.isSearching = false
            $0.searchResults = .init(
                uniqueElements: [Organization(
                    id: "url",
                    name: [LocalizedEntry(value: "geteduroam.nl")],
                    country: "URL",
                    profiles: [Profile(
                        id: "url",
                        name: [LocalizedEntry(value: "geteduroam.nl")],
                        default: true,
                        letsWiFiEndpoint: URL(string: "https://geteduroam.nl")!,
                        type: .letswifi
                    )]
                )]
            )
        }
    }
}
