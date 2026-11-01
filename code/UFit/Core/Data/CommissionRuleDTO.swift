import Foundation

enum UFitCommissionRuleFailure: LocalizedError {
    case document, page, input
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "Les règles reçues sont incohérentes. Actualisez avant de continuer.")
        case .page: String(localized: "La liste a changé. Actualisez les règles pour continuer.")
        case .input: String(localized: "Vérifiez les taux et le motif de cette règle.")
        }
    }
}
enum UFitCommissionRuleContract {
    static let basisPoints = 10_000
    static let initialRevision = 1
    static let revisionStep = 1
    static let maximumRevision = 2_147_483_647
    static let pageLimit = 20
    static let reasonLimit = 500
    static func identifier(_ value: String) -> Bool { UUID(uuidString: value) != nil }
    static func text(_ value: String) -> Bool { !UFitServerTextInput.trimmed(value).isEmpty }
    static func rate(_ value: Int) -> Bool { (.zero...basisPoints).contains(value) }
}
struct UFitCommissionRuleDTO: Decodable, Identifiable {
    let id: String; let scopeId: String; let revision: Int; let previousRuleId: String?
    let brandId: String; let productId: String?; let creatorGradeCode: String?
    let brandName: String; let productName: String?; let creatorGradeLabel: String?
    let baseRateBps: Int; let bonusRateBps: Int; let maxRateBps: Int?; let rateBps: Int
    let active: Bool; let reason: String?; let createdByUserId: String?
    let createdAt: UFitTimestamp; let supersededAt: UFitTimestamp?
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, scopeId, revision, previousRuleId, brandId, productId, creatorGradeCode, brandName, productName, creatorGradeLabel
        case baseRateBps, bonusRateBps, maxRateBps, rateBps, active, reason, createdByUserId, createdAt, supersededAt
    }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCommissionRuleFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        id = try value.decode(String.self, forKey: .id); scopeId = try value.decode(String.self, forKey: .scopeId)
        revision = try value.decode(Int.self, forKey: .revision); previousRuleId = try value.decodeIfPresent(String.self, forKey: .previousRuleId)
        brandId = try value.decode(String.self, forKey: .brandId); productId = try value.decodeIfPresent(String.self, forKey: .productId)
        creatorGradeCode = try value.decodeIfPresent(String.self, forKey: .creatorGradeCode)
        brandName = try value.decode(String.self, forKey: .brandName); productName = try value.decodeIfPresent(String.self, forKey: .productName)
        creatorGradeLabel = try value.decodeIfPresent(String.self, forKey: .creatorGradeLabel)
        baseRateBps = try value.decode(Int.self, forKey: .baseRateBps); bonusRateBps = try value.decode(Int.self, forKey: .bonusRateBps)
        maxRateBps = try value.decodeIfPresent(Int.self, forKey: .maxRateBps); rateBps = try value.decode(Int.self, forKey: .rateBps)
        active = try value.decode(Bool.self, forKey: .active); reason = try value.decodeIfPresent(String.self, forKey: .reason)
        createdByUserId = try value.decodeIfPresent(String.self, forKey: .createdByUserId)
        createdAt = try value.decode(UFitTimestamp.self, forKey: .createdAt); supersededAt = try value.decodeIfPresent(UFitTimestamp.self, forKey: .supersededAt)
        try validate()
    }
    private func validate() throws {
        let ids = [id, scopeId, brandId] + [productId, previousRuleId, createdByUserId].compactMap { $0 }
        let labels = [brandName] + [productName, creatorGradeCode, creatorGradeLabel, reason].compactMap { $0 }
        guard ids.allSatisfy(UFitCommissionRuleContract.identifier), labels.allSatisfy(UFitCommissionRuleContract.text),
              (UFitCommissionRuleContract.initialRevision...UFitCommissionRuleContract.maximumRevision).contains(revision),
              (revision == UFitCommissionRuleContract.initialRevision) == (previousRuleId == nil), previousRuleId != id,
              (productId == nil) == (productName == nil), (creatorGradeCode == nil) == (creatorGradeLabel == nil),
              ([baseRateBps, bonusRateBps, rateBps] + [maxRateBps].compactMap { $0 }).allSatisfy(UFitCommissionRuleContract.rate),
              rateBps == min(baseRateBps + bonusRateBps, maxRateBps ?? UFitCommissionRuleContract.basisPoints) else { throw UFitCommissionRuleFailure.document }
    }
    func matches(brandID: String, productID: String?, gradeCode: String?, configuration: UFitCommissionRuleConfiguration) -> Bool {
        brandId == brandID && productId == productID && creatorGradeCode == gradeCode && baseRateBps == configuration.baseRateBps && bonusRateBps == configuration.bonusRateBps && maxRateBps == configuration.maxRateBps && active == configuration.active && reason == configuration.reason
    }
}
struct UFitCommissionRulePageDTO: Decodable {
    let items: [UFitCommissionRuleDTO]; let nextCursor: String?
    private enum CodingKeys: String, CodingKey, CaseIterable { case items, nextCursor }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCommissionRuleFailure.page)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        items = try value.decode([UFitCommissionRuleDTO].self, forKey: .items); nextCursor = try value.decodeIfPresent(String.self, forKey: .nextCursor)
    }
    func validate(cursor: String?, brandID: String? = nil, historyScopeID: String? = nil) throws {
        guard items.count <= UFitCommissionRuleContract.pageLimit, Set(items.map(\.id)).count == items.count,
              brandID == nil || items.allSatisfy({ $0.brandId == brandID }),
              historyScopeID == nil ? items.allSatisfy({ $0.supersededAt == nil }) : items.allSatisfy({ $0.scopeId == historyScopeID }),
              nextCursor == nil || (items.count == UFitCommissionRuleContract.pageLimit && nextCursor == items.last?.id && nextCursor != cursor) else { throw UFitCommissionRuleFailure.page }
        if historyScopeID != nil {
            guard Set(items.map(\.revision)).count == items.count,
                  zip(items, items.dropFirst()).allSatisfy({ $0.revision > $1.revision }) else { throw UFitCommissionRuleFailure.page }
        }
    }
}
struct UFitCommissionRuleConfiguration: Encodable {
    let baseRateBps: Int; let bonusRateBps: Int; let maxRateBps: Int?; let active: Bool; let reason: String
    private enum CodingKeys: String, CodingKey { case baseRateBps, bonusRateBps, maxRateBps, active, reason }
    func validate() throws {
        guard ([baseRateBps, bonusRateBps] + [maxRateBps].compactMap { $0 }).allSatisfy(UFitCommissionRuleContract.rate),
              UFitServerTextInput.valid(reason, maximum: UFitCommissionRuleContract.reasonLimit), reason == UFitServerTextInput.trimmed(reason) else { throw UFitCommissionRuleFailure.input }
    }
    func encode(to encoder: Encoder) throws {
        try validate()
        var value = encoder.container(keyedBy: CodingKeys.self)
        try value.encode(baseRateBps, forKey: .baseRateBps); try value.encode(bonusRateBps, forKey: .bonusRateBps)
        try value.encode(maxRateBps, forKey: .maxRateBps); try value.encode(active, forKey: .active); try value.encode(reason, forKey: .reason)
    }
}
