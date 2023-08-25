import Foundation
import XMLCoder

public struct Location: Codable, Equatable {
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public let latitude: Double
    public let longitude: Double
    
    enum CodingKeys: String, CodingKey {
        case latitude = "Latitude"
        case longitude = "Longitude"
    }
}
