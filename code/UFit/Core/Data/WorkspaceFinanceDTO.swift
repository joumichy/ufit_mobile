import Foundation

enum UFitWorkspaceFinanceFailure: LocalizedError {
    case document, page
    var errorDescription: String? {
        switch self {
        case .document: Copy.document
        case .page: Copy.page
        }
    }
    private enum Copy {
        static let document = String(localized: "Les chiffres reçus sont incohérents. Actualisez le tableau de bord.")
        static let page = String(localized: "L’historique a changé. Actualisez les commissions pour continuer.")
    }
}
enum UFitWorkspaceSalesBasis: String, Decodable { case orderTotal = "order_total", attributedMerchandise = "attributed_merchandise" }
enum UFitWorkspaceFinanceContract {
    static let persistedCode = "workspace_finance_persisted_invalid"
    static let maximum = 9_007_199_254_740_991
    static let single = 1
    static let basisPoints = 10_000
    static let pageLimit = 20
    static let maximumLimit = 50
    static func integer(_ value: Int) -> Bool { (.zero...maximum).contains(value) }
    static func currency(_ value: String) -> Bool { value.range(of: UFitCurrency.codePattern, options: .regularExpression) != nil }
    static func sum(_ values: [Int]) -> Int? {
        var total = Int.zero
        for value in values {
            let next = total.addingReportingOverflow(value)
            guard !next.overflow else { return nil }; total = next.partialValue
        }
        return total
    }

}
struct UFitWorkspaceSalesCurrencyDTO: Decodable {
    let currency: String
    let capturedOrderCount: Int
    let capturedAmount: Int
    let refundedAmount: Int
    let refundInProgressAmount: Int
    let netAmount: Int
    private enum CodingKeys: String, CodingKey, CaseIterable { case currency, capturedOrderCount, capturedAmount, refundedAmount, refundInProgressAmount, netAmount }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        currency = try value.decode(String.self, forKey: .currency)
        capturedOrderCount = try value.decode(Int.self, forKey: .capturedOrderCount)
        capturedAmount = try value.decode(Int.self, forKey: .capturedAmount)
        refundedAmount = try value.decode(Int.self, forKey: .refundedAmount)
        refundInProgressAmount = try value.decode(Int.self, forKey: .refundInProgressAmount)
        netAmount = try value.decode(Int.self, forKey: .netAmount)
        guard UFitWorkspaceFinanceContract.currency(currency), capturedOrderCount >= UFitWorkspaceFinanceContract.single,
            [capturedOrderCount, capturedAmount, refundedAmount, refundInProgressAmount, netAmount].allSatisfy(UFitWorkspaceFinanceContract.integer),
            UFitWorkspaceFinanceContract.sum([refundedAmount, netAmount]) == capturedAmount,
            let committed = UFitWorkspaceFinanceContract.sum([refundedAmount, refundInProgressAmount]), committed <= capturedAmount else { throw UFitWorkspaceFinanceFailure.document }
    }
}
struct UFitWorkspaceSalesDTO: Decodable {
    let basis: UFitWorkspaceSalesBasis
    let currencies: [UFitWorkspaceSalesCurrencyDTO]
    private enum CodingKeys: String, CodingKey, CaseIterable { case basis, currencies }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        basis = try value.decode(UFitWorkspaceSalesBasis.self, forKey: .basis)
        currencies = try value.decode([UFitWorkspaceSalesCurrencyDTO].self, forKey: .currencies)
        guard Set(currencies.map(\.currency)).count == currencies.count else { throw UFitWorkspaceFinanceFailure.document }
    }
}
struct UFitWorkspaceCommissionCurrencyDTO: Decodable {
    let currency: String
    let originalAmount: Int; let adjustedAmount: Int; let netAmount: Int
    let estimatedAmount: Int; let pendingAmount: Int; let validatedAmount: Int; let paidAmount: Int; let paidAdjustmentAmount: Int
    let estimatedCount: Int; let pendingCount: Int; let validatedCount: Int; let paidCount: Int; let cancelledCount: Int
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case currency, originalAmount, adjustedAmount, netAmount, estimatedAmount, pendingAmount, validatedAmount, paidAmount, paidAdjustmentAmount
        case estimatedCount, pendingCount, validatedCount, paidCount, cancelledCount
    }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        currency = try value.decode(String.self, forKey: .currency)
        originalAmount = try value.decode(Int.self, forKey: .originalAmount); adjustedAmount = try value.decode(Int.self, forKey: .adjustedAmount); netAmount = try value.decode(Int.self, forKey: .netAmount)
        estimatedAmount = try value.decode(Int.self, forKey: .estimatedAmount); pendingAmount = try value.decode(Int.self, forKey: .pendingAmount)
        validatedAmount = try value.decode(Int.self, forKey: .validatedAmount); paidAmount = try value.decode(Int.self, forKey: .paidAmount)
        paidAdjustmentAmount = try value.decode(Int.self, forKey: .paidAdjustmentAmount)
        estimatedCount = try value.decode(Int.self, forKey: .estimatedCount); pendingCount = try value.decode(Int.self, forKey: .pendingCount)
        validatedCount = try value.decode(Int.self, forKey: .validatedCount); paidCount = try value.decode(Int.self, forKey: .paidCount); cancelledCount = try value.decode(Int.self, forKey: .cancelledCount)
        guard UFitWorkspaceFinanceContract.currency(currency),
            [originalAmount, adjustedAmount, netAmount, estimatedAmount, pendingAmount, validatedAmount, paidAmount, paidAdjustmentAmount, estimatedCount, pendingCount, validatedCount, paidCount, cancelledCount].allSatisfy(UFitWorkspaceFinanceContract.integer),
            UFitWorkspaceFinanceContract.sum([adjustedAmount, netAmount]) == originalAmount, paidAdjustmentAmount <= paidAmount,
            let buckets = UFitWorkspaceFinanceContract.sum([estimatedAmount, pendingAmount, validatedAmount, paidAmount]), buckets - paidAdjustmentAmount == netAmount else { throw UFitWorkspaceFinanceFailure.document }
    }
}
struct UFitCreatorDashboardDTO: Decodable {
    struct Profile: Decodable {
        struct Grade: Decodable { let code: String; let label: String; let rank: Int }
        let id: String; let userId: String; let displayName: String; let slug: String; let status: UFitProfileStatus; let grade: Grade
    }
    struct Outfits: Decodable {
        let total: Int; let draft: Int; let scheduled: Int; let published: Int; let archived: Int
        var counts: [Int] { [draft, scheduled, published, archived] }
    }
    struct Performance: Decodable {
        let outfits: Outfits
        let commissions: [UFitWorkspaceCommissionCurrencyDTO]
        let sales: UFitWorkspaceSalesDTO
    }
    let profile: Profile
    let performance: Performance
    func validate(workspace: UFitWorkspaceReference, userID: String) throws {
        guard workspace.isCreator, profile.id == workspace.profileID, profile.userId == userID, profile.status != .suspended,
            UUID(uuidString: profile.id) != nil, !UFitServerTextInput.trimmed(profile.displayName).isEmpty, !UFitServerTextInput.trimmed(profile.grade.label).isEmpty,
            performance.sales.basis == .attributedMerchandise,
            Set(performance.commissions.map(\.currency)).count == performance.commissions.count,
            (performance.outfits.counts + [performance.outfits.total]).allSatisfy(UFitWorkspaceFinanceContract.integer),
            let count = UFitWorkspaceFinanceContract.sum(performance.outfits.counts), count <= performance.outfits.total else { throw UFitWorkspaceFinanceFailure.document }
    }
}
struct UFitBrandDashboardDTO: Decodable {
    struct Profile: Decodable { let id: String; let brandName: String; let slug: String; let status: UFitProfileStatus; let memberRole: UFitBrandMemberRole }
    struct Products: Decodable {
        let total: Int; let draft: Int; let active: Int; let archived: Int
        var counts: [Int] { [draft, active, archived] }
    }
    struct Orders: Decodable {
        let paid: Int; let preparing: Int; let shipped: Int; let delivered: Int; let cancelled: Int; let refunded: Int
        var counts: [Int] { [paid, preparing, shipped, delivered, cancelled, refunded] }
    }
    struct Stock: Decodable { let lowStockVariants: Int }
    struct Performance: Decodable { let products: Products; let orders: Orders; let sales: UFitWorkspaceSalesDTO; let stock: Stock }
    let profile: Profile
    let performance: Performance
    func validate(workspace: UFitWorkspaceReference) throws {
        guard !workspace.isCreator, profile.id == workspace.profileID, UUID(uuidString: profile.id) != nil, profile.status != .suspended,
            !UFitServerTextInput.trimmed(profile.brandName).isEmpty, performance.sales.basis == .orderTotal,
            (performance.products.counts + performance.orders.counts + [performance.products.total, performance.stock.lowStockVariants]).allSatisfy(UFitWorkspaceFinanceContract.integer),
            UFitWorkspaceFinanceContract.sum(performance.products.counts) == performance.products.total else { throw UFitWorkspaceFinanceFailure.document }
    }
}
enum UFitWorkspaceDashboardDocument {
    case creator(UFitCreatorDashboardDTO), brand(UFitBrandDashboardDTO)
}
