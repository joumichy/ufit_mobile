import Foundation

enum UFitParcelTracking {
    static let carrierMaximum = 120
    static let numberMaximum = 160
    static let https = "https"
    static func url(_ value: String) -> URL? {
        guard let url = URL(string: UFitServerTextInput.trimmed(value)), url.scheme?.lowercased() == https,
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
struct UFitParcelPresentation {
    let carrier: String
    let trackingNumber: String
    let trackingURL: URL?
    let sentDate: String
}
