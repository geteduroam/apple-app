import CoreLocation
import Foundation
import Models
import NetworkExtension
import SystemConfiguration.CaptiveNetwork

public class EAPConfigurator {
    public init() { }
    
    // MARK: - Configuring Identity Provider
    
    /// Configure the network for an Identity Provider
    /// - Parameter identityProvider: The Identity Provider
    public func configure(identityProvider: EAPIdentityProvider, credentials: Credentials? = nil) async throws {
        // At this point, we're not certain this configuration can work,
        // but we can't do this any step later, because createNetworkConfigurations will import things to the keychain.
        // TODO: only remove keychain items that match these networks
        let ssids = identityProvider
            .credentialApplicability
            .IEEE80211
            .compactMap {
                $0.ssid
            }
        let domain = identityProvider.id
        removeNetwork(ssids: ssids, domains: [domain])
        
        let configurations = try createNetworkConfigurations(identityProvider: identityProvider, credentials: credentials)
        
        guard let last = configurations.last else {
            throw EAPConfiguratorError.noConfigurations
        }
        try await NEHotspotConfigurationManager.shared.apply(last)
    }
    
    /// Create network configuration object
    /// - Parameter identityProvider: The Identity Provider
    /// - Returns: Network configurations to apply
    private func createNetworkConfigurations(identityProvider: EAPIdentityProvider, credentials: Credentials?) throws -> [NEHotspotConfiguration] {
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
            NSLog("☠️ createNetworkConfigurations: No OID or SSID in configuration")
            throw EAPConfiguratorError.noOIDOrSSID
        }
        
        let eapSettings = try buildSettings(identityProvider: identityProvider, credentials: credentials)
        
        var configurations: [NEHotspotConfiguration] = []
        
        if !oids.isEmpty {
            let domain = identityProvider.id
            
            let hs20 = NEHotspotHS20Settings(
                domainName: domain,
                roamingEnabled: true)
            hs20.roamingConsortiumOIs = oids
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
    private func buildSettings(identityProvider: EAPIdentityProvider, credentials: Credentials?) throws -> NEHotspotEAPSettings {
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
                            NSLog("😡 createNetworkConfigurations: iOS 15.0 and 15.1 do not accept setTrustedServerCertificates - continuing")
                            
                            // On iOS 15.0 and 15.1 we pretend everything went fine while in reality we don't even attempt; it would have crashed later on
                            caImportStatus = true
                        }
                    } else {
                        // We are on iOS 14 or older.
                        // The bug was not yet present prior to iOS 15, so business as usual:
                        caImportStatus = eapSettings.setTrustedServerCertificates(importCACertificates(certificateStrings: caCertificates))
                    }
                    guard caImportStatus else {
                        // This code used to throw at this point, but now we choose to continue instead to see if another method works.
                        // NSLog("☠️ createNetworkConfigurations: setTrustedServerCertificates: returned false")
                        // throw EAPConfiguratorError.failedToSetTrustedServerCertificates
                        return nil
                    }
                }
                
                guard let trustedServerNames, let caCertificates, !trustedServerNames.isEmpty || !caCertificates.isEmpty else {
                    // This code used to throw at this point, but now we choose to continue instead to see if another method works.
                    // NSLog("😱 createNetworkConfigurations: No server names and no custom CAs set; there is no way to verify this network")
                    // throw EAPConfiguratorError.unableToVerifyNetwork
                    return nil
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
            guard let clientSideCredential = authenticationMethod.clientSideCredential,
                  let clientCertificate = clientSideCredential.clientCertificate,
                  let passphrase = clientSideCredential.passphrase,
                  clientCertificate.encoding == "base64",
                  clientCertificate.format == "PKCS12"
            else {
                return nil
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
                    // Add required suffix to username if user didn't specify host
                    if credentials.username.contains("@") {
                        username = credentials.username
                    } else {
                        username = credentials.username + "@" + requiredSuffix
                    }
                    
                    if let hint = clientSideCredential.innerIdentityHint, hint == true {
                        guard username.hasSuffix("@\(requiredSuffix)") else {
                            throw EAPConfiguratorError.invalidUsername(suffix: requiredSuffix)
                        }
                    } else {
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
                throw EAPConfiguratorError.missingCredentials(clientSideCredential)
            }

            let outerEapTypes = identityProvider
                .authenticationMethods
                .methods
                .compactMap {
                    Self.getOuterEapType(outerEapType: $0.EAPMethod.type)
                }
            let outerIdentity = clientSideCredential.outerIdentity
            let innerAuthType = Self.getInnerAuthMethod(innerAuthMethod: 0)
            return try buildSettingsWithUsernamePassword(
                outerEapTypes: outerEapTypes,
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
            NSLog("☠️ configureAP: buildSettingsWithClientCertificate: cannot set identity")
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
        outerEapTypes: [NEHotspotEAPSettings.EAPType],
        outerIdentity: String?,
        innerAuthType: NEHotspotEAPSettings.TTLSInnerAuthenticationType?,
        username: String,
        password: String
    ) throws -> NEHotspotEAPSettings {
        let eapSettings = NEHotspotEAPSettings()
        
        guard username != "" && password != "" else{
            NSLog("☠️ buildSettingsWithUsernamePassword: empty user/pass")
            throw EAPConfiguratorError.emptyUsernameOrPassword
        }
        
        eapSettings.supportedEAPTypes = outerEapTypes.map() { outerEapType in NSNumber(value: outerEapType.rawValue) }
        // TODO: Default value is EAP, should we use that or MSCHAPv2?
        eapSettings.ttlsInnerAuthenticationType = innerAuthType ?? NEHotspotEAPSettings.TTLSInnerAuthenticationType.eapttlsInnerAuthenticationMSCHAPv2
        eapSettings.username = username
        eapSettings.password = password
        //NSLog("🦊 buildSettingsWithUsernamePassword: eapSettings.ttlsInnerAuthenticationType = " + String(eapSettings.ttlsInnerAuthenticationType.rawValue))
        
        if let outerIdentity {
            eapSettings.outerIdentity = outerIdentity
        }
        return eapSettings
    }
    
    // MARK: - Managing Certificates and Keychain
    
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
    
    /**
     @function importCACertificates
     @abstract Import an array of Base64 encoded certificates and return an corresponding array of SecCertificate objects
     @param certificateStrings Array of Base64 CA certificates
     @result Array of SecCertificate certificates
     */
    func importCACertificates(certificateStrings: [String]) -> [SecCertificate] {
        // supporting multiple CAs
        var certificates = [SecCertificate]()
        //NSLog("🦊 configureAP: Start handling caCertificateStrings")
        for caCertificateString in certificateStrings {
            //NSLog("🦊 configureAP: caCertificateString " + caCertificateString)
            guard let certificate: SecCertificate = try? addCertificate(certificate: caCertificateString) else {
                NSLog("☠️ importCACertificates: CA certificate not added")
                continue
            }
            
            certificates.append(certificate)
        }
        
        if certificates.isEmpty {
            NSLog("☠️ importCACertificates: No certificates added")
        } else {
            //NSLog("🦊 configureAP: All caCertificateStrings handled")
        }
        
        return certificates
    }
    
    /**
     @function addCertificate
     @abstract Import Base64 encoded DER to keychain.
     @param certificate Base64 encoded DER encoded X.509 certificate
     @result Whether importing succeeded
     */
    func addCertificate(certificate: String) throws -> SecCertificate {
        guard let data = Data(base64Encoded: certificate) else {
            NSLog("☠️ Unable to base64 decode certificate data")
            throw EAPConfiguratorError.failedToBase64DecodeCertificate
        }
        guard let certificateRef = SecCertificateCreateWithData(kCFAllocatorDefault, data as CFData) else {
            NSLog("☠️ addCertificate: SecCertificateCreateWithData: false")
            throw EAPConfiguratorError.failedToCreateCertificateFromData
        }
        
        var commonNameRef: CFString?
        var status: OSStatus = SecCertificateCopyCommonName(certificateRef, &commonNameRef)
        guard status == errSecSuccess else {
            NSLog("☠️ addCertificate: unable to get common name")
            throw EAPConfiguratorError.failedToCopyCommonName
        }
        let commonName: String = commonNameRef! as String
        
        let addquery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificateRef,
            kSecAttrLabel as String: commonName,
            kSecReturnRef as String: kCFBooleanTrue!,
            //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
            //kSecAttrAccessGroup as String: "ZYJ4TZX4UU.com.apple.networkextensionsharing", // Should be TEAMID.com.apple.networkextensionsharing, but works without?
        ]
        var item: CFTypeRef?
        status = SecItemAdd(addquery as CFDictionary, &item)
        
        // TODO: remove this, and always use the "failsafe"?
        if status == errSecSuccess && item != nil {
            return (item as! SecCertificate)
        }
        
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            NSLog("☠️ addCertificate: SecItemAdd " + String(status))
            throw EAPConfiguratorError.failedSecItemAdd(status)
        }
        
        // FAILSAFE:
        // Instead of returning here, you can also run the code below
        // to make sure that the certificate was added to the KeyChain.
        // This is needed if errSecDuplicateItem was returned earlier.
        // TODO: should we use this flow always?
        
        let getquery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: commonName,
            kSecReturnRef as String: kCFBooleanTrue!,
            //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
            //kSecAttrAccessGroup as String: "ZYJ4TZX4UU.com.apple.networkextensionsharing", // Should be TEAMID.com.apple.networkextensionsharing, but works without?
        ]
        status = SecItemCopyMatching(getquery as CFDictionary, &item)
        guard status == errSecSuccess && item != nil else {
            NSLog("☠️ addCertificate: item is nil after insert and retrieve")
            throw EAPConfiguratorError.failedSecItemCopyMatching(status)
        }
        
        return (item as! SecCertificate)
    }
    
    /// Import a PKCS12 to the keychain and return a handle to the imported item.
    /// - Parameters:
    ///   - certificate: Base64 encoded PKCS12
    ///   - passphrase: Passphrase needed to decrypt the PKCS12, required as Apple doesn't like password-less PKCS12s
    /// - Returns: SecIdentity for added item
    func addClientCertificate(certificate: String, passphrase: String) throws -> SecIdentity {
        // First we call SecPKCS12Import to read the P12,
        // then we call SecItemAdd to add items to the keychain
        // https://developer.apple.com/forums/thread/31711
        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/identities/importing_an_identity
        
        let options = [ kSecImportExportPassphrase as String: passphrase ]
        var rawItems: CFArray?
        let certificateData = Data(base64Encoded: certificate)!
        let statusImport = SecPKCS12Import(certificateData as CFData, options as CFDictionary, &rawItems)
        guard statusImport == errSecSuccess else {
            NSLog("☠️ addClientCertificate: SecPKCS12Import: " + String(statusImport))
            throw EAPConfiguratorError.failedSecPKCS12Import(String(statusImport))
        }
        let items = rawItems! as NSArray
        let item: Dictionary<String,Any> = items.firstObject as! Dictionary<String, Any>
        let identity: SecIdentity = item[kSecImportItemIdentity as String] as! SecIdentity
        let chain = item[kSecImportItemCertChain as String] as! [SecCertificate]
        if items.count > 1 {
            NSLog("😱 addClientCertificate: SecPKCS12Import: more than one result - using only first one")
        }
        
        // Import the identity to the keychain
        let addquery: [String: Any] = [
            //kSecClass as String: kSecClassIdentity, // Gives errSecInternal, according to Apple Developer Technical Support we should not specify this for client certs
            kSecValueRef as String: identity,
            kSecAttrLabel as String: "Identity", // No dual-profile support, so this name will always be unique because we will only have one client cert
            //kSecReturnRef as String: kCFBooleanTrue!, // We're not retrieving the reference at this point, 2nd argument to SecItemAdd is nil
            //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
            //kSecAttrAccessGroup as String: "ZYJ4TZX4UU.com.apple.networkextensionsharing", // Should be TEAMID.com.apple.networkextensionsharing, but works without?
        ]
        var status: OSStatus = SecItemAdd(addquery as CFDictionary, nil)
        guard status == errSecSuccess else {
            // -34018 = errSecMissingEntitlement
            // -26276 = errSecInternal
            NSLog("☠️ addClientCertificate: SecItemAdd: %d", status)
            throw EAPConfiguratorError.failedSecItemAdd(status)
        }
        
        // Import the certificate chain for this identity
        // If we don't do this, we get "failed to find the trust chain for the client certificate" when connecting
        for certificate in chain {
            let certificateRef: SecCertificate = certificate as SecCertificate
            var commonNameRef: CFString?
            var status: OSStatus = SecCertificateCopyCommonName(certificateRef, &commonNameRef)
            guard status == errSecSuccess else {
                NSLog("☠️ addClientCertificate: unable to get common name")
                continue
            }
            let commonName: String = commonNameRef! as String
            
            let addquery: [String: Any] = [
                kSecClass as String: kSecClassCertificate,
                kSecValueRef as String: certificate,
                kSecAttrLabel as String: commonName,
                //kSecReturnRef as String: kCFBooleanTrue!, // We're not retrieving the reference at this point, 2nd argument to SecItemAdd is nil
                //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
                kSecAttrAccessGroup as String: "ZYJ4TZX4UU.com.apple.networkextensionsharing", // TEAMID.com.apple.networkextensionsharing
            ]
            
            status = SecItemAdd(addquery as CFDictionary, nil)
            
            guard status == errSecSuccess || status == errSecDuplicateItem else {
                NSLog("☠️ addClientCertificate: SecItemAdd: %s: %d", commonName, status)
                throw EAPConfiguratorError.failedSecItemAdd(status, commonName: commonName)
            }
        }
        
        // Now we will retrieve the identity from the keychain again
        var newIdentity: SecIdentity
        let getquery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: "Identity",
            kSecReturnRef as String: kCFBooleanTrue!,
            //kSecReturnPersistentRef as String: kCFBooleanTrue!, // Persistent refs cause an error (invalid EAP config) when installing the profile
            kSecAttrAccessGroup as String: "ZYJ4TZX4UU.com.apple.networkextensionsharing", // TEAMID.com.apple.networkextensionsharing
        ]
        var ref: CFTypeRef?
        status = SecItemCopyMatching(getquery as CFDictionary, &ref)
        guard status == errSecSuccess else {
            NSLog("☠️ addClientCertificate: SecItemCopyMatching: retrieving identity returned %d", status)
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
    
    
    func fetchNetworkInfo() throws -> [NetworkInfo] {
        guard let interfaces: NSArray = CNCopySupportedInterfaces() else {
            throw EAPConfiguratorError.cannotCopySupportedInterfaces
        }
        
        return interfaces.map { interface in
            let interfaceName = interface as! String
            let success: Bool
            let ssid: String?
            let bssid: String?
            if let dict = CNCopyCurrentNetworkInfo(interfaceName as CFString) as NSDictionary? {
                success = true
                ssid = dict[kCNNetworkInfoKeySSID as String] as? String
                bssid = dict[kCNNetworkInfoKeyBSSID as String] as? String
            } else {
                success = false
                ssid = nil
                bssid = nil
            }
            return NetworkInfo(interface: interfaceName, success: success, ssid: ssid, bssid: bssid)
        }
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
}
