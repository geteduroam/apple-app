import Foundation
import Models
import UIKit

extension LogoData {
    
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
}
