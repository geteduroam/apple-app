import Foundation
import Models
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension LogoData {
    
#if os(iOS)
    var image: UIImage? {
        let imageData: Data
        switch encoding {
        case "base64":
            guard let base64EncodedData = value.data(using: .utf8), let data = Data(base64Encoded: base64EncodedData) else {
                return nil
            }
            imageData = data
        default:
            // Unrecognized encoding
            return nil
        }
        return UIImage(data: imageData)
    }
#elseif os(macOS)
    var image: NSImage? {
        let imageData: Data
        switch encoding {
        case "base64":
            guard let base64EncodedData = value.data(using: .utf8), let data = Data(base64Encoded: base64EncodedData) else {
                return nil
            }
            imageData = data
        default:
            // Unrecognized encoding
            return nil
        }
        return NSImage(data: imageData)
    }
#endif
}
