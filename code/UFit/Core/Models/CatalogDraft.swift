import Foundation

enum UFitCatalogGender: String, Codable, CaseIterable, Identifiable {
    case male, female, unisex
    var id: String { rawValue }
    var label: String { switch self { case .male: Copy.male; case .female: Copy.female; case .unisex: Copy.unisex } }
    private enum Copy { static let male = String(localized: "Homme"); static let female = String(localized: "Femme"); static let unisex = String(localized: "Unisexe") }
}
enum UFitCatalogImageKind: String, Codable, CaseIterable, Identifiable {
    case product, worn, detail, lookbook
    var id: String { rawValue }
    var label: String { switch self { case .product: Copy.product; case .worn: Copy.worn; case .detail: Copy.detail; case .lookbook: Copy.lookbook } }
    private enum Copy { static let product = String(localized: "Produit"); static let worn = String(localized: "Porté"); static let detail = String(localized: "Détail"); static let lookbook = String(localized: "Lookbook") }
}
struct UFitCatalogCurrency: Codable, Hashable, Identifiable {
    let code: String
    let minorUnitDigits: Int
    var id: String { code }
}
enum UFitCatalogInput {
    static let defaultCurrency = "CHF"
    static let nameMin = 2; static let nameMax = 120; static let descriptionMin = 1; static let descriptionMax = 6000
    static let categoryMin = 1; static let categoryMax = 100; static let detailsMax = 2000; static let skuMin = 1; static let skuMax = 120
    static let optionMax = 100; static let variantsMax = 100; static let photosMax = 12; static let integerMin = 0; static let integerMax = 2147483647
    static let decimalRadix = 10; static let comma = ","; static let point = "."; static let zeroDigit = "0"
    static let amountPattern = #"^[0-9]+(?:[.,][0-9]+)?$"#
    static let integerPattern = #"^[0-9]+$"#
    static let firstComponent = 0; static let fractionalComponent = 1; static let minimumComponents = 1
    static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func integer(_ text: String) -> Int? {
        let value = trimmed(text)
        guard value.range(of: integerPattern, options: .regularExpression) != nil,
              let amount = Int(value), (integerMin...integerMax).contains(amount) else { return nil }
        return amount
    }
    static func minorUnits(_ text: String, currency: UFitCatalogCurrency) -> Int? {
        let value = trimmed(text)
        guard currency.minorUnitDigits >= integerMin, value.range(of: amountPattern, options: .regularExpression) != nil else { return nil }
        let parts = value.replacingOccurrences(of: comma, with: point).components(separatedBy: point)
        let fraction = parts.count > minimumComponents ? parts[fractionalComponent] : String()
        guard fraction.count <= currency.minorUnitDigits, let whole = Int(parts[firstComponent]) else { return nil }
        var amount = whole
        for digit in fraction + String(repeating: zeroDigit, count: currency.minorUnitDigits - fraction.count) {
            guard let digitValue = digit.wholeNumberValue else { return nil }
            let product = amount.multipliedReportingOverflow(by: decimalRadix)
            let sum = product.partialValue.addingReportingOverflow(digitValue)
            guard !product.overflow, !sum.overflow, sum.partialValue <= integerMax else { return nil }
            amount = sum.partialValue
        }
        return (integerMin...integerMax).contains(amount) ? amount : nil
    }
    static func amountText(_ amount: Int, currency: UFitCatalogCurrency) -> String {
        guard currency.minorUnitDigits > integerMin else { return String(amount) }
        let digits = String(amount)
        let padding = max(integerMin, currency.minorUnitDigits + minimumComponents - digits.count)
        let padded = String(repeating: zeroDigit, count: padding) + digits
        let split = padded.index(padded.endIndex, offsetBy: -currency.minorUnitDigits)
        return String(padded[..<split]) + comma + String(padded[split...])
    }
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
enum UFitCatalogPhotoTransfer: Equatable { case ready, uploading, failed(String) }
struct UFitCatalogPhotoDraft: Identifiable, Equatable {
    let id: UUID
    let serverID: String?
    var source: String?
    var url: String?
    var kind: UFitCatalogImageKind
    var transfer: UFitCatalogPhotoTransfer
    var previewData: Data? = nil
}
struct UFitCatalogProductDraft: Equatable {
    var name = String(); var description = String(); var category = String(); var gender: UFitCatalogGender?
    var price = String(); var currency = UFitCatalogInput.defaultCurrency; var material = String(); var care = String()
    var variants: [UFitCatalogVariantDraft] = []; var photos: [UFitCatalogPhotoDraft] = []
}
enum UFitCatalogField: Hashable { case name, description, category, price, currency, material, care, variants, photos }
enum UFitCatalogVariantField: Hashable { case sku, size, color, stock, price }
