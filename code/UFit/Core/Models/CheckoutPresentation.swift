import Foundation

struct UFitShippingAddress: Codable, Equatable {
    var fullName = String()
    var line1 = String()
    var line2: String?
    var postalCode = String()
    var city = String()
    var country = "CH"
    var phone: String?
}
enum UFitCheckoutStep: Hashable { case address, review, confirming, paid }
struct UFitCheckoutSummary {
    let subtotal: String
    let shipping: String
    let taxes: String
    let total: String
    let returnPolicy: String
    let taxNotice: String
    let customsNotice: String
}
