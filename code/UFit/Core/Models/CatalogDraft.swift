import Foundation

enum UFitCatalogImageKind: String, Codable, CaseIterable, Identifiable {
    case product, worn, detail, lookbook
    var id: String { rawValue }
    var label: String { switch self { case .product: Copy.product; case .worn: Copy.worn; case .detail: Copy.detail; case .lookbook: Copy.lookbook } }
    private enum Copy { static let product = String(localized: "Produit"); static let worn = String(localized: "Porté"); static let detail = String(localized: "Détail"); static let lookbook = String(localized: "Lookbook") }
}
enum UFitCatalogInput {
    static let defaultCurrency = "CHF"
    static let nameMin = 2; static let nameMax = 120; static let descriptionMin = 1; static let descriptionMax = 6000
    static let categoryMin = 1; static let categoryMax = 100; static let detailsMax = 2000; static let skuMin = 1; static let skuMax = 120
    static let optionMax = 100; static let variantsMax = 100; static let photosMax = 12; static let integerMin = 0; static let integerMax = UFitDecimalInput.maximumInteger
    static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func countValid(_ text: String, minimum: Int, maximum: Int) -> Bool { (minimum...maximum).contains(trimmed(text).unicodeScalars.count) }
}
struct UFitCatalogVariantDraft: Identifiable, Equatable {
    let id: UUID
    let serverID: String?
    let expectedStockQuantity: Int?
    var sku: String
    var size: String
    var color: String
    var stock: String
    var priceOverride: String
    var status: UFitCatalogVariantStatus
    init(id: UUID = UUID(), serverID: String? = nil, expectedStockQuantity: Int? = nil, sku: String = String(), size: String = String(), color: String = String(), stock: String = String(), priceOverride: String = String(), status: UFitCatalogVariantStatus = .active) {
        self.id = id; self.serverID = serverID; self.expectedStockQuantity = expectedStockQuantity; self.sku = sku; self.size = size; self.color = color; self.stock = stock; self.priceOverride = priceOverride; self.status = status
    }
    var title: String { let parts = [size, color].map(UFitCatalogInput.trimmed).filter { !$0.isEmpty }; return parts.isEmpty ? sku : parts.joined(separator: Copy.separator) }
    private enum Copy { static let separator = " · " }
}
struct UFitCatalogPhotoDraft: Identifiable, Equatable {
    let id: UUID
    let serverID: String?
    var source: String?
    var url: String?
    var kind: UFitCatalogImageKind
    var transfer: UFitPhotoTransfer
    var previewData: Data? = nil
    var canRetryUpload: Bool { if case .failed = transfer { url == nil } else { false } }
}
struct UFitCatalogProductDraft: Equatable {
    var name = String(); var description = String(); var category = String(); var gender: UFitGenderTarget?
    var price = String(); var currency = UFitCatalogInput.defaultCurrency; var material = String(); var care = String()
    var variants: [UFitCatalogVariantDraft] = []; var photos: [UFitCatalogPhotoDraft] = []
}
enum UFitCatalogField: Hashable { case name, description, category, price, currency, material, care, variants, photos }
enum UFitCatalogVariantField: Hashable { case sku, size, color, stock, price }
