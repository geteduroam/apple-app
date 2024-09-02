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
    case failedSecItemAdd(OSStatus, label: String? = nil)
    
    /// Unable to copy from keychain
    case failedSecItemCopyMatching(OSStatus)
    
    /// Unable to decode certificate dat
    case failedToBase64DecodeCertificate
    
    /// Unable to create certificate from data
    case failedToCreateCertificateFromData
    
    /// Unable to get common name or subject sequence f from certificate
    case failedToCopyCommonNameOrSubjectSequence
    
    /// No valid configuration found
    case noConfigurations
    
    /// Unable to read supported interfaces
    case cannotCopySupportedInterfaces
    
    /// No credentials in configuration
    case missingCredentials(ClientCredential, requiredSuffix: String?)
    
    /// No password in configuration
    case missingPassword(ClientCredential)
    
    /// Username must end with
    case invalidUsername(suffix: String)
    
    /// No valid client certificate in configuration
    case noValidClientCertificate
}

extension EAPConfiguratorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noOIDOrSSID:
            return NSLocalizedString("No OID or SSID in configuration", bundle: .module, comment: "No OID or SSID in configuration")
            
        case .failedToSetTrustedServerCertificates:
            return NSLocalizedString("Unable to set server certificate as trusted", bundle: .module, comment: "setTrustedServerCertificates: returned false")
            
        case .unableToVerifyNetwork:
            return NSLocalizedString("Unable to verify network because no server name or certificate set", bundle: .module, comment: "No server names and no custom CAs set")
            
        case .cannotSetIdentity:
            return NSLocalizedString("Unable to set identity for client certificate", bundle: .module, comment: "ClientCertificate: cannot set identity")
            
        case .emptyUsernameOrPassword:
            return NSLocalizedString("No credentials in configuration", bundle: .module, comment: "empty user/pass")
            
        case .noOuterEAPType:
            return NSLocalizedString("No valid outer EAP type in configuration", bundle: .module, comment: "noOuterEAPType")
            
        case let .failedSecPKCS12Import(status):
            return String(format: NSLocalizedString("Unable to import certificate into keychain (%d)", bundle: .module, comment: "addClientCertificate"), status)
            
        case let .failedSecItemAdd(status, label):
            return String(format: NSLocalizedString("Unable to add certificate %@ to keychain (%d)", bundle: .module, comment: "addClientCertificate: SecItemAdd"), label ?? NSLocalizedString("with unknown name", bundle: .module, comment: "with unknown name"), status)
            
        case let .failedSecItemCopyMatching(status):
            return String(format: NSLocalizedString("Unable to copy from keychain (%d)", bundle: .module, comment: "SecItemCopyMatching: retrieving identity returned"), status)
            
        case .failedToBase64DecodeCertificate:
            return NSLocalizedString("Unable to decode certificate data", bundle: .module, comment: "Unable to base64 decode certificate data")
            
        case .failedToCreateCertificateFromData:
            return NSLocalizedString("Unable to create certificate from data", bundle: .module, comment: "SecCertificateCreateWithData: false")
            
        case .failedToCopyCommonNameOrSubjectSequence:
            return NSLocalizedString("Unable to get common name from certificate", bundle: .module, comment: "Certificate: unable to get common name or subject sequence ")
            
        case .noConfigurations:
            return NSLocalizedString("No valid configuration found", bundle: .module, comment: "noConfigurations")
            
        case .cannotCopySupportedInterfaces:
            return NSLocalizedString("Unable to read supported interfaces", bundle: .module, comment: "cannotCopySupportedInterfaces")
            
        case .missingCredentials:
            return NSLocalizedString("No credentials in configuration", bundle: .module, comment: "empty user/pass")
            
        case .missingPassword:
            return NSLocalizedString("No password in configuration", bundle: .module, comment: "empty pass")
            
        case let .invalidUsername(suffix):
            return String(format: NSLocalizedString("Username must end with \"%@\"", bundle: .module, comment: "invalid username"), suffix)
            
        case .noValidClientCertificate:
            return NSLocalizedString("No valid client certificate in configuration", bundle: .module, comment: "noValidClientCertificate")
        }
    }
}
