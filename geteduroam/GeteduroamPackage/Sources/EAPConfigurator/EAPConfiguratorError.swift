import Foundation
import Models

public enum EAPConfiguratorError: Error {
    /// No OID or SSID in configuration
    case noOIDOrSSID
    
    /// Unable to set server certificate as trusted
    case failedToSetTrustedServerCertificates
    
    /// Unable to verify network because no server name or certificate set
    case unableToVerifyNetwork
    
    /// Unable to set identity for client certificate
    case cannotSetIdentity
    
    /// No credentials in configuration
    case emptyUsernameOrPassword
    
    /// No valid outer EAP type in configuration
    case noOuterEAPType
    
    /// Unable to import certificate into keychain
    case failedSecPKCS12Import(OSStatus)
    
    /// Unable to add certificate to keychain
    case failedSecItemAdd(OSStatus, commonName: String? = nil)
    
    /// Unable to copy from keychain
    case failedSecItemCopyMatching(OSStatus)
    
    /// Unable to decode certificate dat
    case failedToBase64DecodeCertificate
    
    /// Unable to create certificate from data
    case failedToCreateCertificateFromData
    
    /// Unable to get common name from certificate
    case failedToCopyCommonName
    
    /// No valid configuration found
    case noConfigurations
    
    /// Unable to read supported interfaces
    case cannotCopySupportedInterfaces
    
    /// No credentials in configuration
    case missingCredentials(ClientCredential)
    
    /// Username must end with
    case invalidUsername(suffix: String)
}

extension EAPConfiguratorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noOIDOrSSID:
            return NSLocalizedString("No OID or SSID in configuration", comment: "No OID or SSID in configuration")
            
        case .failedToSetTrustedServerCertificates:
            return NSLocalizedString("Unable to set server certificate as trusted", comment: "setTrustedServerCertificates: returned false")
            
        case .unableToVerifyNetwork:
            return NSLocalizedString("Unable to verify network because no server name or certificate set", comment: "No server names and no custom CAs set")
            
        case .cannotSetIdentity:
            return NSLocalizedString("Unable to set identity for client certificate", comment: "ClientCertificate: cannot set identity")
            
        case .emptyUsernameOrPassword:
            return NSLocalizedString("No credentials in configuration", comment: "empty user/pass")
            
        case .noOuterEAPType:
            return NSLocalizedString("No valid outer EAP type in configuration", comment: "noOuterEAPType")
            
        case let .failedSecPKCS12Import(status):
            return String(format: NSLocalizedString("Unable to import certificate into keychain (%d)", comment: "addClientCertificate"), status)
            
        case let .failedSecItemAdd(status, commonName):
            return String(format: NSLocalizedString("Unable to add certificate %@ to keychain (%d)", comment: "addClientCertificate: SecItemAdd"), commonName ?? NSLocalizedString("with unknown name", comment: "with unknown name"), status)
            
        case let .failedSecItemCopyMatching(status):
            return String(format: NSLocalizedString("Unable to copy from keychain (%d)", comment: "SecItemCopyMatching: retrieving identity returned"), status)
            
        case .failedToBase64DecodeCertificate:
            return NSLocalizedString("Unable to decode certificate data", comment: "Unable to base64 decode certificate data")
            
        case .failedToCreateCertificateFromData:
            return NSLocalizedString("Unable to create certificate from data", comment: "SecCertificateCreateWithData: false")
            
        case .failedToCopyCommonName:
            return NSLocalizedString("Unable to get common name from certificate", comment: "Certificate: unable to get common name")
            
        case .noConfigurations:
            return NSLocalizedString("No valid configuration found", comment: "noConfigurations")
            
        case .cannotCopySupportedInterfaces:
            return NSLocalizedString("Unable to read supported interfaces", comment: "cannotCopySupportedInterfaces")
            
        case .missingCredentials:
            return NSLocalizedString("No credentials in configuration", comment: "empty user/pass")
            
        case let .invalidUsername(suffix):
            return String(format: NSLocalizedString("Username must end with \"%@\"", comment: "invalid username"), suffix)
        }
    }
}
