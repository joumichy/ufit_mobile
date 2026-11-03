import Foundation

enum UFitWorkspaceFinanceKind { case creator, brand }
struct UFitWorkspaceActivityFigure: Identifiable {
    enum Key: String { case outfits, published, draft, scheduled, archived, products, active, paid, preparing, shipped, delivered, cancelled, refunded, lowStock }
    let id: Key
    let label: String
    let value: Int
}
struct UFitWorkspaceSalesFigure: Identifiable {
    let currency: String
    let orderCount: Int
    let captured: String
    let refunded: String
    let inProgress: String
    let net: String
    let hasRefundInProgress: Bool
    var id: String { currency }
    var ordersLabel: String {
        orderCount == Counts.single ? String(localized: "1 commande encaissée") : String(localized: "\(orderCount) commandes encaissées")
    }
    private enum Counts { static let single = 1 }
}
struct UFitWorkspaceCommissionFigure: Identifiable {
    let currency: String
    let original: String
    let adjusted: String
    let net: String
    let estimated: String
    let pending: String
    let validated: String
    let paid: String
    let paidAdjustment: String
    let hasPaidAdjustment: Bool
    var id: String { currency }
}
struct UFitWorkspaceDashboardPresentation {
    let name: String
    let kind: UFitWorkspaceFinanceKind
    let status: String
    let grade: String?
    let activity: [UFitWorkspaceActivityFigure]
    let sales: [UFitWorkspaceSalesFigure]
    let commissions: [UFitWorkspaceCommissionFigure]
}
