import SwiftUI

struct OnboardingSlide: Identifiable {
    let id: Int
    let systemImage: String
    let title: String
    let description: String
}

struct Outfit: Identifiable {
    let id: String
    let imageName: String
    let creator: String
    let creatorAvatar: String
    let price: String
    let likes: Int
    let comments: Int
    let title: String
    let description: String
    let currency: String
    let totalPrice: Int?
    let sourceCreatorId: String?
    let sourceOutfitId: String?
    let products: [OutfitProduct]
    let pieces: [OutfitPiece]
}

struct OutfitProduct: Identifiable {
    let id: String
    let systemImage: String
    let name: String
    let productID: String?
    let brandID: String?
}

struct OutfitPiece: Identifiable {
    let id: String
    let name: String
    let brand: String
    let price: String
    let sizes: [String]
    let productID: String?
    let isRequired: Bool
    let isShoppable: Bool
}

struct BrandOrder: Identifiable {
    let id: String
    let customer: String
    let items: Int
    let total: String
    let status: OrderStatus
    let date: String
}

enum OrderStatus {
    case pending
    case shipped
    case delivered

    init(apiStatus: String) {
        switch apiStatus {
        case "shipped":
            self = .shipped
        case "delivered":
            self = .delivered
        default:
            self = .pending
        }
    }

    var label: String {
        switch self {
        case .pending: "À expédier"
        case .shipped: "Expédié"
        case .delivered: "Livré"
        }
    }

    var foreground: Color {
        switch self {
        case .pending: .amberText
        case .shipped: .blueText
        case .delivered: .greenText
        }
    }

    var background: Color {
        switch self {
        case .pending: .amberBackground
        case .shipped: .blueBackground
        case .delivered: .greenBackground
        }
    }
}
