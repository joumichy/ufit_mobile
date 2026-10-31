import Foundation

struct UFitShippingAddress: Encodable {
    var fullName: String
    var line1: String
    var line2: String?
    var postalCode: String
    var city: String
    var country: String
    var phone: String?
}
