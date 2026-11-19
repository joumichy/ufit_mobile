import Foundation

enum UFitRefundPolicy: String, Codable {
    case proportionalTaxFullShippingV1 = "proportional_tax_full_shipping_v1"
    var explanation: String {
        switch self {
        case .proportionalTaxFullShippingV1:
            String(localized: "Les pièces retournées et leur part de taxes sont remboursées. Les frais de livraison initiaux sont remboursés avec le retour des dernières pièces de la commande. Les frais externes de renvoi ou de douane ne sont pas inclus.")
        }
    }
}
