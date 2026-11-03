import Foundation

struct UFitBrandOrderPresentation {
    let summary: UFitOrderSummary
    let items: [UFitOrderPiece]
    let address: [String]
    let phone: String?
    let subtotal: String
    let shipping: String
    let taxes: String
    let total: String
    let shipment: UFitShipmentPresentation?
    let commands: [UFitShipmentCommand]
    var cancellationNote: String? = nil
}
enum UFitBrandOrderInput {
    static let statuses = UFitOrderLifecycle.allCases.filter { $0 != .pendingPayment }
    static let separator = " · "
    static let space = " "
}
