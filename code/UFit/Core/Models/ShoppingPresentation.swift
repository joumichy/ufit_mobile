import Foundation

struct UFitOutfitGalleryPhoto: Decodable, Identifiable {
    let url: String
    let position: Int
    let id: String
}

struct UFitVariantChoice: Identifiable {
    let id: String
    let label: String
    let isAvailable: Bool
}
struct UFitShoppingPiece: Identifiable {
    let id: String
    let itemType: UFitOutfitItemType?
    let name: String
    let brand: String?
    let brandID: String?
    let image: String?
    let price: String
    let note: String?
    let variants: [UFitVariantChoice]
    let selectedVariantID: String?
    let quantity: Int
    let maximumQuantity: Int
    let isBusy: Bool
    let wasAdded: Bool
    let issue: String?
}
struct UFitCartPresentationLine: Identifiable {
    let id: String
    let name: String
    let variant: String
    let image: String?
    let quantity: Int
    let maximumQuantity: Int
    let amount: String
    let isBusy: Bool
    let isAvailable: Bool
}
