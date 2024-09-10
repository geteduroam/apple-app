import AuthClient
import ComposableArchitecture
import MockNetwork
import Models
import XCTest
@testable import Connect
@testable import HotspotNetworkClient
import XMLCoder

@MainActor
final class ConnectTests: XCTestCase {
    
    static let eapConfigEndpoint = URL(string: "https://www.example.com/eapconfig")!
    static let letsWifiEndpoint = URL(string: "https://www.example.com/letswifi")!
    
    let demoInstance = Organization(id: "cat_7016", name: [LocalizedEntry(value: "Môreelsepark Cöllege")], country: "NL", profiles: [
        Profile(id: "letswifi_cat_7830", name: [LocalizedEntry(value: "Mijn Moreelsepark")], default: true, letsWiFiEndpoint: ConnectTests.letsWifiEndpoint, type: .letswifi),
        Profile(id: "profile2", name: [LocalizedEntry(value: "Profile")], eapConfigEndpoint: ConnectTests.eapConfigEndpoint, type: .eapConfig)
    ], geo: [Coordinate(lat: 52.088999999999999, lon: 5.1130000000000004)])
    
    #if !os(macOS) // TODO: Write tests for macOS
    func testInvalidEAPConfig() async throws {
        let store = TestStore(
            initialState: Connect.State(organization: demoInstance),
            reducer: { Connect() },
            withDependencies: {
                var urlRequest = URLRequest(url: ConnectTests.eapConfigEndpoint)
                urlRequest.httpMethod = "GET"
                let networkExchange = NetworkExchange(
                    urlRequest: urlRequest,
                    response: ServerResponse(
                        data: #"<text>This isn't a valid profile!</text>"#.data(using: .utf8)
                    )
                )
                class Mock: MockURLProtocol { }
                $0.urlSession = Mock.session(exchange: networkExchange)
            })
        
        await store.send(.onAppear)
        
        await store.send(.select("profile2")) {
            $0.selectedProfileId = "profile2"
        }
        
        await store.send(.connect) {
            $0.loadingState = .isLoading
        }
        
        await store.receive(\.connectResponse) {
            $0.loadingState = .failure
            $0.destination = .alert(AlertState(title: TextState("Failed to connect"), message: TextState("No valid provider found.")))
        }
    }

    func testValidEAPConfig() async throws {
        let config = EAPIdentityProviderList(
            providers: [.init(
                id: "test",
                validUntil: Date(timeIntervalSince1970: 3600),
                authenticationMethods: .init(
                    methods: [.init(
                        EAPMethod: .init(type: 13),
 
                            serverSideCredential: .init(
                                certificates: [.init(value: "", format: "", encoding: "")],
                                serverIDs: [""]
                            ),
                            clientSideCredential: .init(
                                outerIdentity: "",
                                innerIdentityPrefix: "",
                                innerIdentitySuffix: "",
                                innerIdentityHint: true,
                                userName: "",
                                password: "",
                                clientCertificate: .init(value: "", format: "", encoding: ""),
                                intermediateCACertificates: [.init(value: "", format: "", encoding: "")],
                                passphrase: "",
                                PAC: "",
                                provisionPAC: false,
                                allowSave: true
                            ), innerAuthenticationMethods: []
                    )]
                ),
                credentialApplicability: .init(
                    IEEE80211: [
                        EEE80211Properties(consortiumOID: "5a03ba0000"),
                        EEE80211Properties(consortiumOID: "5a03ba0800"),
                        EEE80211Properties(consortiumOID: "001bc50460"),
                        EEE80211Properties(ssid: "ssid", minRSNProto: .CCMP)],
                    IEEE8023: []
                ),
                providerInfo: .init(
                    displayName: [LocalizedStringEntry(language: "en", value: "English Test Config")],
                    description: [.init(value: "")],
                    providerLocations: [.init(latitude: 53, longitude: 5)],
                    providerLogo: .init(value: "", mime: "", encoding: ""),
                    termsOfUse: nil,
                    helpdesk: .init(
                        emailAdress: [.init(value: "helpdesk@example.com")],
                        webAddress: [
                            .init(language: "en", value: "https://www.example.com/en"),
                            .init(language: "nl", value: "https://www.example.com/nl")
                        ],
                        phone: [.init(value: "+31-555-123456")]
                    )
                )
            )]
        )
        
        let eapConfigData = #"""
                            <EAPIdentityProviderList>
                                <EAPIdentityProvider>
                                    <ID>test</ID>
                                    <ValidUntil>1970-01-01T01:00:00Z</ValidUntil>
                                    <AuthenticationMethods>
                                        <AuthenticationMethod>
                                            <EAPMethod>
                                                <Type>13</Type>
                                            </EAPMethod>
                                            <ServerSideCredential>
                                                <CA format="X.509" encoding="base64">MIIEMjCCAxqgAwIBAgIBATANBgkqhkiG9w0BAQUFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTA0MDEwMTAwMDAwMFoXDTI4MTIzMTIzNTk1OVowezELMAkGA1UEBhMCR0IxGzAZBgNVBAgMEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBwwHU2FsZm9yZDEaMBgGA1UECgwRQ29tb2RvIENBIExpbWl0ZWQxITAfBgNVBAMMGEFBQSBDZXJ0aWZpY2F0ZSBTZXJ2aWNlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL5AnfRu4ep2hxxNRUSOvkbIgwadwSr+GB+O5AL686tdUIoWMQuaBtDFcCLNSS1UY8y2bmhGC1Pqy0wkwLxyTurxFa70VJoSCsN6sjNg4tqJVfMiWPPe3M/vg4aijJRPn2jymJBGhCfHdr/jzDUsi14HZGWCwEiwqJH5YZ92IFCokcdmtet4YgNW8IoaE+oxox6gmf049vYnMlhvB/VruPsUK6+3qszWY19zjNoFmag4qMsXeDZRrOme9Hg6jc8P2ULimAyrL58OAd7vn5lJ8S3frHRNG5i1R8XlKdH5kBjHYpy+g8cmez6KJcfA3Z3mNWgQIJ2P2N7Sw4ScDV7oL8kCAwEAAaOBwDCBvTAdBgNVHQ4EFgQUoBEKIz6W8Qfs4q8p74Klf9AwpLQwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wewYDVR0fBHQwcjA4oDagNIYyaHR0cDovL2NybC5jb21vZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNqA0oDKGMGh0dHA6Ly9jcmwuY29tb2RvLm5ldC9BQUFDZXJ0aWZpY2F0ZVNlcnZpY2VzLmNybDANBgkqhkiG9w0BAQUFAAOCAQEACFb8AvCb6P+k+tZ7xkSAzk/ExfYAWMymtrwUSWgEdujm7l3sAg9g1o1QGE8mTgHj5rCl7r+8dFRBv/38ErjHT1r0iWAFf2C3BUrz9vHCv8S5dIa2LX1rzNLzRt0vxuBqw8M0Ayx9lt1awg6nCpnBBYurDC/zXDrPbDdVCYfeU0BsWO/8tqtlbgT2G9w84FoVxp7Z8VlIMCFlA2zs6SFz7JsDoeA3raAVGI/6ugLOpyypEBMs1OUIJqsil2D4kF501KKaU73yqWjgom7C12yxow+ev+to51byrvLjKzg6CYG1a4XXvi3tPxq3smPi9WIsgtRqAEFQ8TmDn5XpNpaYbg==</CA>
                                                <ServerID>radius.geteduroam.nl</ServerID>
                                            </ServerSideCredential>
                                            <ClientSideCredential>
                                                <OuterIdentity>sdrswiz0hx2yrai5@moreelsepark.geteduroam.nl</OuterIdentity>
                                                <ClientCertificate format="PKCS12" encoding="base64">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</ClientCertificate>
                                                <Passphrase>pkcs12</Passphrase>
                                            </ClientSideCredential>
                                        </AuthenticationMethod>
                                    </AuthenticationMethods>
                                    <CredentialApplicability>
                                        <IEEE80211>
                                            <ConsortiumOID>5a03ba0000</ConsortiumOID>
                                        </IEEE80211>
                                        <IEEE80211>
                                            <ConsortiumOID>5a03ba0800</ConsortiumOID>
                                        </IEEE80211>
                                        <IEEE80211>
                                            <ConsortiumOID>001bc50460</ConsortiumOID>
                                        </IEEE80211>
                                        <IEEE80211>
                                            <SSID>ssid</SSID>
                                            <MinRSNProto>CCMP</MinRSNProto>
                                        </IEEE80211>
                                    </CredentialApplicability>
                                    <ProviderInfo>
                                        <DisplayName>
                                            <lang>en</lang>English Test Config</DisplayName>
                                        <Description></Description>
                                        <ProviderLocation>
                                            <Latitude>53.0</Latitude>
                                            <Longitude>5.0</Longitude>
                                        </ProviderLocation>
                                        <ProviderLogo>
                                            <mime></mime>
                                            <encoding></encoding>
                                        </ProviderLogo>
                                        <Helpdesk>
                                            <EmailAdress>helpdesk@example.com</EmailAdress>
                                            <WebAddress>
                                                <lang>en</lang>https://www.example.com/en</WebAddress>
                                            <WebAddress>
                                                <lang>nl</lang>https://www.example.com/nl</WebAddress>
                                            <Phone>+31-555-123456</Phone>
                                        </Helpdesk>
                                    </ProviderInfo>
                                </EAPIdentityProvider>
                            </EAPIdentityProviderList>
                            """#.data(using: .utf8)
        
        let store = TestStore(
            initialState: Connect.State(organization: demoInstance),
            reducer: { Connect() },
            withDependencies: {
                var urlRequest = URLRequest(url: ConnectTests.eapConfigEndpoint)
                urlRequest.httpMethod = "GET"
                let networkExchange = NetworkExchange(
                    urlRequest: urlRequest,
                    response: ServerResponse(
                        data: eapConfigData
                    )
                )
                class Mock: MockURLProtocol { }
                $0.urlSession = Mock.session(exchange: networkExchange)
                $0.date.now = Date(timeIntervalSince1970: 0)
                $0.eapClient.configure = { provider, credentials, dryRun, _, _ in
                    return ["ssid"]
                }
                $0.notificationClient.scheduleRenewReminder = { validUntil, organizationId, organizationURLString, profileId in
                    XCTAssertEqual(validUntil, Date(timeIntervalSince1970: 3600))
                    XCTAssertEqual(organizationId, "cat_7016")
                    XCTAssertEqual(profileId, "profile2")
                }
                $0.notificationClient.unscheduleRenewReminder = { }
                $0.hotspotNetworkClient.fetchCurrent = {
                    NetworkInfo(ssid: "ssid", bssid: "", signalStrength: 1, isSecure: true, didAutoJoin: false, didJustJoin: true, isChosenHelper: true)
                }
                $0.defaultFileStorage = .inMemory
            })
        
        await store.send(.onAppear)
        
        await store.send(.select("profile2")) {
            $0.selectedProfileId = "profile2"
        }
        
        await store.send(.connect) {
            $0.loadingState = .isLoading
        }
        
        let providerInfo = config.providers[0].providerInfo
        await store.receive(\.connectResponse) {
            $0.loadingState = .isLoading
            $0.providerInfo = providerInfo
            $0.configuredConnection = .init(
                organizationType: .id("cat_7016"),
                profileId: "profile2",
                type: .ssids(expectedSSIDs: ["ssid"]),
                validUntil: Date(timeIntervalSince1970: 3600),
                providerInfo: .init(
                    displayName: [LocalizedStringEntry(language: "en", value: "English Test Config")],
                    description: [.init(value: "")],
                    providerLocations: [.init(latitude: 53, longitude: 5)],
                    providerLogo: .init(value: "", mime: "", encoding: ""),
                    termsOfUse: nil,
                    helpdesk: .init(
                        emailAdress: [.init(value: "helpdesk@example.com")],
                        webAddress: [
                            .init(language: "en", value: "https://www.example.com/en"),
                            .init(language: "nl", value: "https://www.example.com/nl")
                        ],
                        phone: [.init(value: "+31-555-123456")]
                    )
                )
            )
        }
        
        await store.receive(\.connectResponse) {
            $0.loadingState = .success(.disconnected, .ssids(expectedSSIDs: ["ssid"]), validUntil: Date(timeIntervalSince1970: 3600))
        }
        
        await store.receive(\.foundSSID) {
            $0.loadingState = .success(.connected, .ssids(expectedSSIDs: ["ssid"]), validUntil: Date(timeIntervalSince1970: 3600))
        }
        
        await store.send(.onDisappear)
    }
    #endif
}
