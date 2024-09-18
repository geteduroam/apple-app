import AppRemoteConfigClient
import CoreLocation
import Dependencies
import Foundation
import Models
import NetworkExtension
import OSLog
import SystemConfiguration.CaptiveNetwork
import XCTestDynamicOverlay

public struct EAPClient: Sendable {
    public var configure: @Sendable (EAPIdentityProvider, Credentials?, Bool, IgnoreServerCertificateImportFailureEnabled?, IgnoreMissingServerCertificateNameEnabled?) async throws -> [String]
}

extension DependencyValues {
    public var eapClient: EAPClient {
        get { self[EAPClientKey.self] }
        set { self[EAPClientKey.self] = newValue }
    }
    
    public enum EAPClientKey: TestDependencyKey {
        public static let testValue = EAPClient.mock
    }
}

extension EAPClient {
    static let mock: Self = .init(
        configure: unimplemented()
    )
}

extension DependencyValues.EAPClientKey: DependencyKey {
    public static let liveValue = EAPClient.live
}

extension EAPClient {
    static let live: Self = .init(
        configure: {
            identityProvider,
            credentials,
            dryRun,
            ignoreServerCertificateImportFailureEnabled,
            ignoreMissingServerCertificateNameEnabled in
#if os(iOS)
            try await EAPConfigurator(teamID: "ZYJ4TZX4UU").configure(
                identityProvider: identityProvider,
                credentials: credentials,
                dryRun: dryRun,
                ignoreServerCertificateImportFailureEnabled: ignoreServerCertificateImportFailureEnabled,
                ignoreMissingServerCertificateNameEnabled: ignoreMissingServerCertificateNameEnabled
            )
#else
            fatalError("EAPConfigurator not available")
#endif
        }
    )
}

extension Logger {
    static let eap = Logger(subsystem: Bundle.main.bundleIdentifier ?? "EAPConfigurator", category: "eap")
}

class EAPConfigurator {
#if os(iOS)
    let teamID: String
    let appName: String
    
    init(teamID: String, appName: String = Bundle.main.bundleIdentifier ?? "") {
        self.teamID = teamID
        self.appName = appName
    }
    
    // MARK: - Configuring Identity Provider
    
    /// Configure the network for an Identity Provider
    /// - Parameters:
    ///   - identityProvider: The Identity Provider
    ///   - credentials: Credentials entered by user
    ///   - dryRun: If true only checks if information is complete without actually applying the network settings
    /// - Returns: Expected SSIDs for connection
    func configure(
        identityProvider: EAPIdentityProvider,
        credentials: Credentials? = nil,
        dryRun: Bool,
        ignoreServerCertificateImportFailureEnabled: IgnoreServerCertificateImportFailureEnabled?,
        ignoreMissingServerCertificateNameEnabled: IgnoreMissingServerCertificateNameEnabled?
    ) async throws -> [String] {
        // At this point, we're not certain this configuration can work,
        // but we can't do this any step later, because createNetworkConfigurations will import things to the keychain.
        let name = identityProvider.providerInfo?.displayName?.localized() ?? "unnamed identity provider"
        Logger.eap.info("Started configuring for \(name) \(dryRun ? "with dry run" : "")")
        let ssids = identityProvider
            .credentialApplicability
            .IEEE80211
            .compactMap {
                $0.ssid
            }
        let domain = identityProvider.id
        if !dryRun {
            Logger.eap.info("Removing network(s) \(ssids)")
            removeNetwork(ssids: ssids, domains: [domain])
            
            Logger.eap.info("Removing previous private keys from keychain")
            deletePrivateKeys(named: "Identity")
            deletePrivateKeys(named: "Identity \(appName)")
        }
        
        Logger.eap.info("Creating network configurations")
        let configurations = try createNetworkConfigurations(
            identityProvider: identityProvider,
            credentials: credentials,
            ignoreServerCertificateImportFailure: ignoreServerCertificateImportFailureEnabled != nil,
            ignoreMissingServerCertificateName: ignoreMissingServerCertificateNameEnabled != nil
        )
        
        guard configurations.isEmpty == false else {
            throw EAPConfiguratorError.noConfigurations
        }
        
        if !dryRun {
            Logger.eap.info("Applying network configurations")
            for configuration in configurations {
                Logger.eap.debug("Applying network configuration \(configuration.debugDescription)")
                try await NEHotspotConfigurationManager.shared.apply(configuration)
            }
        }
        
        Logger.eap.info("Listing private keys")
        listPrivateKeys(named: "Identity")
        listPrivateKeys(named: "Identity \(appName)")
        
        Logger.eap.info("Finished configuring for \(name) \(dryRun ? "with dry run" : "")")
        return ssids
    }
    
    /// Create network configuration object
    /// - Parameter identityProvider: The Identity Provider
    /// - Returns: Network configurations to apply
    private func createNetworkConfigurations(
        identityProvider: EAPIdentityProvider,
        credentials: Credentials?,
        ignoreServerCertificateImportFailure: Bool,
        ignoreMissingServerCertificateName: Bool
    ) throws -> [NEHotspotConfiguration] {
        let oids = identityProvider
            .credentialApplicability
            .IEEE80211
            .compactMap {
                $0.consortiumOID
            }
        
        let ssids = identityProvider
            .credentialApplicability
            .IEEE80211
            .compactMap {
                $0.ssid
            }
        
        guard !oids.isEmpty || !ssids.isEmpty else {
            Logger.eap.error("createNetworkConfigurations: No OID or SSID in configuration")
            throw EAPConfiguratorError.noOIDOrSSID
        }
        
        let eapSettings = try buildSettings(
            identityProvider: identityProvider,
            credentials: credentials,
            ignoreServerCertificateImportFailure: ignoreServerCertificateImportFailure,
            ignoreMissingServerCertificateName: ignoreMissingServerCertificateName
        )
        
        var configurations: [NEHotspotConfiguration] = []
        
        if !oids.isEmpty {
            let domain = identityProvider.id
            
            let hs20 = NEHotspotHS20Settings(
                domainName: domain,
                roamingEnabled: true)
            hs20.roamingConsortiumOIs = oids.map { $0.uppercased() } // See https://github.com/geteduroam/ionic-app/pull/120
            configurations.append(NEHotspotConfiguration(hs20Settings: hs20, eapSettings: eapSettings))
        }
        
        for ssid in ssids {
            configurations.append(NEHotspotConfiguration(ssid: ssid, eapSettings: eapSettings))
        }
        
        guard !configurations.isEmpty else {
            throw EAPConfiguratorError.noConfigurations
        }
        
        return configurations
    }
    
    ///  Create a Hotspot EAP settings object
    /// - Parameter identityProvider: The Identity Provider
    /// - Returns: Hotspot EAP settings object
    private func buildSettings(
        identityProvider: EAPIdentityProvider,
        credentials: Credentials?,
        ignoreServerCertificateImportFailure: Bool,
        ignoreMissingServerCertificateName: Bool
    ) throws -> NEHotspotEAPSettings {
        let settings = try identityProvider
            .authenticationMethods
            .methods
            .compactMap { authenticationMethod -> NEHotspotEAPSettings? in
                let eapSettings = try buildSettings(identityProvider: identityProvider, authenticationMethod: authenticationMethod, credentials: credentials)
                
                let trustedServerNames = authenticationMethod.serverSideCredential?.serverIDs
                if let eapSettings, let trustedServerNames, !trustedServerNames.isEmpty {
                    eapSettings.trustedServerNames = trustedServerNames
                }
                
                let caCertificates = authenticationMethod.serverSideCredential?.certificates.compactMap { certificateData -> String? in
                    guard certificateData.encoding == "base64", certificateData.format == "X.509" else {
                        return nil
                    }
                    return certificateData.value
                }
                if let eapSettings, let caCertificates, !caCertificates.isEmpty {
                    let caImportStatus: Bool
                    if #available(iOS 15, *) {
                        // iOS 15.0.* and iOS 15.1.* have a bug where we cannot call setTrustedServerCertificates,
                        // or the profile will be deemed invalid.
                        // Not calling it makes the profile trust the CA bundle from the OS,
                        // so only server name validation is performed.
                        if #available(iOS 15.2, *) {
                            // The bug was fixed in iOS 15.2, business as usual:
                            caImportStatus = eapSettings.setTrustedServerCertificates(importCACertificates(certificateStrings: caCertificates))
                        } else {
                            Logger.eap.info("createNetworkConfigurations: iOS 15.0 and 15.1 do not accept setTrustedServerCertificates - continuing")
                            
                            // On iOS 15.0 and 15.1 we pretend everything went fine while in reality we don't even attempt; it would have crashed later on
                            caImportStatus = true
                        }
                    } else {
                        // We are on iOS 14 or older.
                        // The bug was not yet present prior to iOS 15, so business as usual:
                        caImportStatus = eapSettings.setTrustedServerCertificates(importCACertificates(certificateStrings: caCertificates))
                    }
                    guard caImportStatus || ignoreServerCertificateImportFailure else {
                        // This code used to throw at this point, but now we choose to continue instead to see if another method works.
                        Logger.eap.warning("createNetworkConfigurations: setTrustedServerCertificates: returned false")
                        // throw EAPConfiguratorError.failedToSetTrustedServerCertificates
                        return nil
                    }
                }
                
                if !ignoreMissingServerCertificateName {
                    guard let trustedServerNames, let caCertificates, !trustedServerNames.isEmpty || !caCertificates.isEmpty else {
                        // This code used to throw at this point, but now we choose to continue instead to see if another method works.
                        Logger.eap.warning("createNetworkConfigurations: No server names and no custom CAs set; there is no way to verify this network")
                        // throw EAPConfiguratorError.unableToVerifyNetwork
                        return nil
                    }
                }
                
                if let eapSettings {
                    eapSettings.isTLSClientCertificateRequired = false
                }
                
                return eapSettings
            }
            .first
        
        guard let settings else {
            throw EAPConfiguratorError.noOuterEAPType
        }
        
        return settings
    }
    
    /// Create a Hotspot EAP settings object for a specific authentication method
    /// - Parameters:
    ///   - identityProvider: The Identity Provider
    ///   - authenticationMethod: The authentication method
    /// - Returns: Hotspot EAP settings object
    private func buildSettings(identityProvider: EAPIdentityProvider, authenticationMethod: AuthenticationMethod, credentials: Credentials?) throws -> NEHotspotEAPSettings? {
        guard let outerEapType = Self.getOuterEapType(outerEapType: authenticationMethod.EAPMethod.type) else {
            return nil
        }
        switch outerEapType {
        case .EAPTLS:
            guard let clientSideCredential = authenticationMethod.clientSideCredential else {
                return nil
            }
            guard let clientCertificate = clientSideCredential.clientCertificate,
                  let passphrase = clientSideCredential.passphrase ?? credentials?.password,
                  clientCertificate.encoding == "base64",
                  clientCertificate.format == "PKCS12"
            else {
                throw EAPConfiguratorError.noValidClientCertificate
            }
            
            guard passphrase.isEmpty == false else {
                throw EAPConfiguratorError.missingPassword(clientSideCredential)
            }
            
            let clientCertificateData = clientCertificate.value
            return try buildSettingsWithClientCertificate(
                pkcs12: clientCertificateData,
                passphrase: passphrase
            )
            
        case .EAPTTLS, .EAPFAST, .EAPPEAP:
            guard let clientSideCredential = authenticationMethod.clientSideCredential else {
                return nil
            }
            let username: String
            let password: String
            
            if let clientSideUsername = clientSideCredential.userName,
               let clientSidePassword = clientSideCredential.password,
               clientSideUsername.isEmpty == false,
               clientSidePassword.isEmpty == false {
                username = clientSideUsername
                password = clientSidePassword
            } else if let credentials,
                      credentials.username.isEmpty == false,
                      credentials.password.isEmpty == false  {
                if let requiredSuffix = clientSideCredential.innerIdentitySuffix {
                    if let hint = clientSideCredential.innerIdentityHint, hint == true {
                        // Add required suffix to username if user didn't specify host
                        if credentials.username.contains("@") {
                            username = credentials.username
                        } else {
                            username = credentials.username + "@" + requiredSuffix
                        }
                        
                        guard username.hasSuffix("@\(requiredSuffix)") else {
                            throw EAPConfiguratorError.invalidUsername(suffix: requiredSuffix)
                        }
                    } else {
                        username = credentials.username
                        
                        guard username.hasSuffix("@\(requiredSuffix)") || username.hasSuffix(".\(requiredSuffix)") else {
                            throw EAPConfiguratorError.invalidUsername(suffix: requiredSuffix)
                        }
                        guard username.contains("@") else {
                            throw EAPConfiguratorError.invalidUsername(suffix: requiredSuffix)
                        }
                    }
                } else {
                    username = credentials.username
                }
                password = credentials.password
            } else {
                // An required empty string as suffix makes no sense
                let requiredSuffix = clientSideCredential.innerIdentitySuffix != "" ? clientSideCredential.innerIdentitySuffix : nil
                throw EAPConfiguratorError.missingCredentials(clientSideCredential, requiredSuffix: requiredSuffix)
            }

            let outerIdentity = clientSideCredential.outerIdentity
            let innerAuthType = authenticationMethod
                .innerAuthenticationMethods
                .compactMap { method -> NEHotspotEAPSettings.TTLSInnerAuthenticationType? in
                    if let innerEAPAuthMethodRaw = method.EAPMethod?.type, let innerEAPAuthMethod = Self.getInnerAuthMethod(innerAuthMethod: innerEAPAuthMethodRaw) {
                        return innerEAPAuthMethod
                    } else if let innerNonEAPAuthMethodRaw = method.nonEAPAuthMethod?.type.rawValue, let innerNonEAPAuthMethod = Self.getInnerAuthMethod(innerAuthMethod: -innerNonEAPAuthMethodRaw)  {
                        return innerNonEAPAuthMethod
                    }
                    return nil
                }
                .first ?? .eapttlsInnerAuthenticationMSCHAPv2
            return try buildSettingsWithUsernamePassword(
                outerEapType: outerEapType,
                outerIdentity: outerIdentity,
                innerAuthType: innerAuthType,
                username: username,
                password: password
            )
            
        @unknown default:
            return nil
        }
    }
    
    ///  Create NEHotspotEAPSettings object for client certificate authentication
    /// - Parameters:
    ///   - pkcs12: Base64 encoded client certificate
    ///   - passphrase: Passphrase to decrypt the pkcs12, Apple doesn't like password-less
    /// - Returns: NEHotspotEAPSettings configured with the provided credentials
    private func buildSettingsWithClientCertificate(
        pkcs12: String,
        passphrase: String
    ) throws -> NEHotspotEAPSettings {
        let eapSettings = NEHotspotEAPSettings()
        eapSettings.supportedEAPTypes = [NSNumber(value: NEHotspotEAPSettings.EAPType.EAPTLS.rawValue)]
        
        // TODO: certName should be the CN of the certificate,
        // but this works as long as we have only one (which we currently do)
        let identity = try addClientCertificate(certificate: pkcs12, passphrase: passphrase)
        
        guard eapSettings.setIdentity(identity) else {
            Logger.eap.error("configureAP: buildSettingsWithClientCertificate: cannot set identity")
            throw EAPConfiguratorError.cannotSetIdentity
        }
        
        return eapSettings
    }
    
    /// Create NEHotspotEAPSettings object for username/pass authentication
    /// - Parameters:
    ///   - outerEapTypes: Outer EAP Types
    ///   - outerIdentity: Outer identity
    ///   - innerAuthType: Inner auth types
    ///   - username: username for PEAP/TTLS authentication
    ///   - password: password for PEAP/TTLS authentication
    /// - Returns:  NEHotspotEAPSettings configured with the provided credentials
    private func buildSettingsWithUsernamePassword(
        outerEapType: NEHotspotEAPSettings.EAPType,
        outerIdentity: String?,
        innerAuthType: NEHotspotEAPSettings.TTLSInnerAuthenticationType,
        username: String,
        password: String
    ) throws -> NEHotspotEAPSettings {
        Logger.eap.info("buildSettingsWithUsernamePassword: outerEapType = \(outerEapType.rawValue)")
        
        let eapSettings = NEHotspotEAPSettings()
        
        guard username != "" && password != "" else{
            Logger.eap.error("buildSettingsWithUsernamePassword: empty user/pass")
            throw EAPConfiguratorError.emptyUsernameOrPassword
        }
        
        eapSettings.supportedEAPTypes = [NSNumber(value: outerEapType.rawValue)]
        eapSettings.ttlsInnerAuthenticationType = innerAuthType
        eapSettings.username = username
        eapSettings.password = password
        Logger.eap.info("buildSettingsWithUsernamePassword: eapSettings.ttlsInnerAuthenticationType = \(eapSettings.ttlsInnerAuthenticationType.rawValue)")
        
        if let outerIdentity {
            eapSettings.outerIdentity = outerIdentity
        }
        return eapSettings
    }
    
    // MARK: - Managing Certificates and Keychain
    func listKeychain() {
        listAllKeysForSecClass(kSecClassGenericPassword)
        listAllKeysForSecClass(kSecClassInternetPassword)
        listAllKeysForSecClass(kSecClassCertificate)
        listAllKeysForSecClass(kSecClassKey)
        listAllKeysForSecClass(kSecClassIdentity)
    }
    
    ///  Clear all items in this app's Keychain
    func resetKeychain() {
        deleteAllKeysForSecClass(kSecClassGenericPassword)
        deleteAllKeysForSecClass(kSecClassInternetPassword)
        deleteAllKeysForSecClass(kSecClassCertificate)
        deleteAllKeysForSecClass(kSecClassKey)
        deleteAllKeysForSecClass(kSecClassIdentity)
    }
    
    /**
     @function deleteAllKeysForSecClass
     @abstract Clear Keychain for given class
     @param secClass Class to clear
     */
    func deleteAllKeysForSecClass(_ secClass: CFTypeRef) {
        let dict: [NSString: CFTypeRef] = [kSecClass: secClass]
        let result = SecItemDelete(dict as CFDictionary)
        assert(result == noErr || result == errSecItemNotFound, "Error deleting keychain data (\(result))")
    }
  
    func listAllKeysForSecClass(_ secClass: CFTypeRef) {
        let dict: [NSString: CFTypeRef] = [
            kSecClass: secClass,
            kSecReturnData: kCFBooleanTrue,
            kSecReturnAttributes: kCFBooleanTrue,
            kSecReturnRef: kCFBooleanTrue,
            kSecMatchLimit: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let result = SecItemCopyMatching(dict as CFDictionary, &items)
        let securityClass = "\(secClass)"
        Logger.eap.info("\(securityClass): \(String(describing: items))")
        assert(result == noErr || result == errSecItemNotFound, "Error listing keychain data (\(result))")
    }
    
    func deletePrivateKeys(named: String) {
        let dict: [NSString: CFTypeRef] = [
            kSecClass: kSecClassIdentity,
            kSecAttrLabel: named as CFTypeRef
        ]
        let result = SecItemDelete(dict as CFDictionary)
        assert(result == noErr || result == errSecItemNotFound, "Error deleting private keys (\(result))")
    }
    
    func listPrivateKeys(named: String) {
        let dict: [NSString: CFTypeRef] = [
            kSecClass: kSecClassIdentity,
            kSecAttrLabel: named as CFTypeRef,
            kSecReturnData: kCFBooleanTrue,
            kSecReturnAttributes: kCFBooleanTrue,
            kSecReturnRef: kCFBooleanTrue,
            kSecMatchLimit: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let result = SecItemCopyMatching(dict as CFDictionary, &items)
        let securityClass = "Private keys named \(named)"
        Logger.eap.info("\(securityClass): \(String(describing: items))")
        assert(result == noErr || result == errSecItemNotFound, "Error listing keychain data (\(result))")
    }
    
    /**
     @function importCACertificates
     @abstract Import an array of Base64 encoded certificates and return an corresponding array of SecCertificate objects
     @param certificateStrings Array of Base64 CA certificates
     @result Array of SecCertificate certificates
     */
    private func importCACertificates(certificateStrings: [String]) -> [SecCertificate] {
        // supporting multiple CAs
        var certificates = [SecCertificate]()
        Logger.eap.info("Start handling CA certificate strings")
        for caCertificateString in certificateStrings {
            Logger.eap.info("Handling CA certificate string: \(caCertificateString)")
            guard let certificate: SecCertificate = try? addCertificate(certificate: caCertificateString) else {
                Logger.eap.error("CA certificate not added")
                continue
            }
            certificates.append(certificate)
        }
        
        if certificates.isEmpty {
            Logger.eap.warning("No certificates imported")
        } else {
            Logger.eap.info("All certificates imported")
        }
        
        return certificates
    }
    
    
    private func label(for certificateRef: SecCertificate) throws -> String {
        var commonNameRef: CFString?
        let status: OSStatus = SecCertificateCopyCommonName(certificateRef, &commonNameRef)
        if status == errSecSuccess {
            return commonNameRef! as String
        }
        
        guard let rawSubject = SecCertificateCopyNormalizedSubjectSequence(certificateRef) as? Data else {
            Logger.eap.error("addCertificate: unable to get common name or subject sequence from certificate")
            throw EAPConfiguratorError.failedToCopyCommonNameOrSubjectSequence
        }
        
        return rawSubject.base64EncodedString(options: [])
    }
    
    /**
     @function addCertificate
     @abstract Import Base64 encoded DER to keychain.
     @param certificate Base64 encoded DER encoded X.509 certificate
     @result Whether importing succeeded
     */
    private func addCertificate(certificate: String) throws -> SecCertificate {
        guard let data = Data(base64Encoded: certificate) else {
            Logger.eap.error("Unable to base64 decode certificate data")
            throw EAPConfiguratorError.failedToBase64DecodeCertificate
        }
        guard let certificateRef = SecCertificateCreateWithData(kCFAllocatorDefault, data as CFData) else {
            Logger.eap.error("addCertificate: SecCertificateCreateWithData: false")
            throw EAPConfiguratorError.failedToCreateCertificateFromData
        }
        
        let label = try label(for: certificateRef)
        Logger.eap.info("addCertificate: adding \(label)")
    
        let addquery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificateRef,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: kCFBooleanTrue!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
            kSecAttrAccessGroup as String: "\(teamID).com.apple.networkextensionsharing"
        ]
        var item: CFTypeRef?
        var status = SecItemAdd(addquery as CFDictionary, &item)
        
        // TODO: remove this, and always use the "failsafe"?
        if status == errSecSuccess && item != nil {
            return (item as! SecCertificate)
        }
        
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            Logger.eap.error("addCertificate: SecItemAdd \(String(status), privacy: .public)")
            throw EAPConfiguratorError.failedSecItemAdd(status)
        }
        
        // FAILSAFE:
        // Instead of returning here, you can also run the code below
        // to make sure that the certificate was added to the KeyChain.
        // This is needed if errSecDuplicateItem was returned earlier.
        // TODO: should we use this flow always?
        
        let getquery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: kCFBooleanTrue!,
            //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
            kSecAttrAccessGroup as String: "\(teamID).com.apple.networkextensionsharing"
        ]
        status = SecItemCopyMatching(getquery as CFDictionary, &item)
        guard status == errSecSuccess && item != nil else {
            Logger.eap.error("addCertificate: item is nil after insert and retrieve")
            throw EAPConfiguratorError.failedSecItemCopyMatching(status)
        }
        
        return (item as! SecCertificate)
    }
    
    /// Import a PKCS12 to the keychain and return a handle to the imported item.
    /// - Parameters:
    ///   - certificate: Base64 encoded PKCS12
    ///   - passphrase: Passphrase needed to decrypt the PKCS12, required as Apple doesn't like password-less PKCS12s
    /// - Returns: SecIdentity for added item
    private func addClientCertificate(certificate: String, passphrase: String) throws -> SecIdentity {
        // First we call SecPKCS12Import to read the P12,
        // then we call SecItemAdd to add items to the keychain
        // https://developer.apple.com/forums/thread/31711
        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/identities/importing_an_identity
        
        let options = [ kSecImportExportPassphrase as String: passphrase ]
        var rawItems: CFArray?
        let certificateData = Data(base64Encoded: certificate)!
        let statusImport = SecPKCS12Import(certificateData as CFData, options as CFDictionary, &rawItems)
        guard statusImport == errSecSuccess else {
            Logger.eap.error("addClientCertificate: SecPKCS12Import: \(String(statusImport), privacy: .public)")
            throw EAPConfiguratorError.failedSecPKCS12Import(statusImport)
        }
        let items = rawItems! as NSArray
        let item: Dictionary<String,Any> = items.firstObject as! Dictionary<String, Any>
        let identity: SecIdentity = item[kSecImportItemIdentity as String] as! SecIdentity
        let chain = item[kSecImportItemCertChain as String] as! [SecCertificate]
        if items.count > 1 {
            Logger.eap.warning("addClientCertificate: SecPKCS12Import: more than one result - using only first one")
        }
        
        // Import the identity to the keychain
        let addquery: [String: Any] = [
            //kSecClass as String: kSecClassIdentity, // Gives errSecInternal, according to Apple Developer Technical Support we should not specify this for client certs
            kSecValueRef as String: identity,
            kSecAttrLabel as String: "Identity \(appName)", // Unique per app
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            //kSecReturnRef as String: kCFBooleanTrue!, // We're not retrieving the reference at this point, 2nd argument to SecItemAdd is nil
            //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
            kSecAttrAccessGroup as String: "\(teamID).com.apple.networkextensionsharing"
        ]
        var status: OSStatus = SecItemAdd(addquery as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            // -34018 = errSecMissingEntitlement
            // -26276 = errSecInternal
            // -25299 = errSecDuplicateItem
            Logger.eap.error("addClientCertificate: SecItemAdd: \(String(status), privacy: .public)")
            throw EAPConfiguratorError.failedSecItemAdd(status)
        }
        
        // Import the certificate chain for this identity
        // If we don't do this, we get "failed to find the trust chain for the client certificate" when connecting
        for certificate in chain {
            let certificateRef: SecCertificate = certificate as SecCertificate
            
            let label = try label(for: certificateRef)
            Logger.eap.info("addClientCertificate: adding \(label)")
            
            let addquery: [String: Any] = [
                kSecClass as String: kSecClassCertificate,
                kSecValueRef as String: certificate,
                kSecAttrLabel as String: label,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                //kSecReturnRef as String: kCFBooleanTrue!, // We're not retrieving the reference at this point, 2nd argument to SecItemAdd is nil
                //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
                kSecAttrAccessGroup as String: "\(teamID).com.apple.networkextensionsharing"
            ]
            
            let status = SecItemAdd(addquery as CFDictionary, nil)
            
            guard status == errSecSuccess || status == errSecDuplicateItem else {
                Logger.eap.error("addClientCertificate: SecItemAdd: \(label, privacy: .public) \(String(status), privacy: .public)")
                throw EAPConfiguratorError.failedSecItemAdd(status, label: label)
            }
        }
        
        // Now we will retrieve the identity from the keychain again
        var newIdentity: SecIdentity
        let getquery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: "Identity \(appName)",
            kSecReturnRef as String: kCFBooleanTrue!,
            //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
            kSecAttrAccessGroup as String: "\(teamID).com.apple.networkextensionsharing",
        ]
        var ref: CFTypeRef?
        status = SecItemCopyMatching(getquery as CFDictionary, &ref)
        guard status == errSecSuccess else {
            Logger.eap.error("addClientCertificate: SecItemCopyMatching: \(String(status), privacy: .public)")
            throw EAPConfiguratorError.failedSecItemCopyMatching(status)
        }
        newIdentity = ref! as! SecIdentity
        
        return newIdentity
    }
    
    // MARK: - Managing Networks
    
    enum NetworkAssociationResult {
        case noNetworksFound
        case associated
        case missing
    }
    
    /**
     @function isNetworkAssociated
     @abstract Capacitor call to check if SSID is connect, doesn't work for HS20
     @param call Capacitor call object containing array "ssid"
     */
    func isNetworkAssociated(ssid: String) async -> NetworkAssociationResult {
        let configuredSSIDs = await NEHotspotConfigurationManager.shared.configuredSSIDs()
        
        guard !configuredSSIDs.isEmpty else { return .noNetworksFound }
        
        if configuredSSIDs.contains(ssid) {
            return .associated
        } else {
            return .missing
        }
    }
    
    /**
     @function removeConfiguration
     @abstract Capacitor call to remove a network
     @param call Capacitor call object containing array "ssid" and/or string "domain"
     */
    func removeNetwork(ssids: [String] = [], domains: [String] = []) {
        for ssid in ssids {
            NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        }
        for domain in domains {
            NEHotspotConfigurationManager.shared.removeConfiguration(forHS20DomainName: domain)
        }
    }
    
    /**
     @function getInnerAuthMethod
     @abstract Convert inner auth method integer to NEHotspotEAPSettings.TTLSInnerAuthenticationType enum
     @param innerAuthMethod Integer representing an auth method
     @result NEHotspotEAPSettings.TTLSInnerAuthenticationType representing the given auth method
     */
    class func getInnerAuthMethod(innerAuthMethod: Int?) -> NEHotspotEAPSettings.TTLSInnerAuthenticationType? {
        switch innerAuthMethod {
        case -1: // Non-EAP PAP
            return .eapttlsInnerAuthenticationPAP
        case -2: // Non-EAP MSCHAP
            return .eapttlsInnerAuthenticationMSCHAP
        case -3: // Non-EAP MSCHAPv2
            return .eapttlsInnerAuthenticationMSCHAPv2
            /*
             case _: // not in XSD
             return .eapttlsInnerAuthenticationCHAP
             */
        case 26: // EAP-MSCHAPv2 (Apple supports only this inner EAP type)
            return .eapttlsInnerAuthenticationEAP
        default:
            return nil
        }
    }
    
    /**
     @function getOuterEapType
     @abstract Convert outer EAP type integer to NEHotspotEAPSettings enum
     @param outerEapType Integer representing an EAP type
     @result NEHotspotEAPSettings.EAPType representing the given EAP type
     */
    class func getOuterEapType(outerEapType: Int) -> NEHotspotEAPSettings.EAPType? {
        switch outerEapType {
        case 13:
            return NEHotspotEAPSettings.EAPType.EAPTLS
        case 21:
            return NEHotspotEAPSettings.EAPType.EAPTTLS
        case 25:
            return NEHotspotEAPSettings.EAPType.EAPPEAP
        case 43:
            return NEHotspotEAPSettings.EAPType.EAPFAST
        default:
            return nil
        }
    }
#endif
}
