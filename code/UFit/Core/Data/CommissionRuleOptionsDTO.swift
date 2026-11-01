import Foundation

enum UFitCommissionOptionKind: String, Decodable { case brands, products, grades }
protocol UFitCommissionOption: Decodable, Identifiable where ID == String {
    static var kind: UFitCommissionOptionKind { get }
}
struct UFitCommissionBrandOption: UFitCommissionOption {
    static let kind = UFitCommissionOptionKind.brands
    let id: String; let brandName: String; let status: UFitProfileStatus
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, brandName, status }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCommissionRuleFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        id = try value.decode(String.self, forKey: .id); brandName = try value.decode(String.self, forKey: .brandName); status = try value.decode(UFitProfileStatus.self, forKey: .status)
        guard UFitCommissionRuleContract.identifier(id), UFitCommissionRuleContract.text(brandName) else { throw UFitCommissionRuleFailure.document }
    }
}
struct UFitCommissionProductOption: UFitCommissionOption {
    static let kind = UFitCommissionOptionKind.products
    let id: String; let brandId: String; let name: String; let status: UFitCatalogStatus
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, brandId, name, status }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCommissionRuleFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        id = try value.decode(String.self, forKey: .id); brandId = try value.decode(String.self, forKey: .brandId)
        name = try value.decode(String.self, forKey: .name); status = try value.decode(UFitCatalogStatus.self, forKey: .status)
        guard [id, brandId].allSatisfy(UFitCommissionRuleContract.identifier), UFitCommissionRuleContract.text(name) else { throw UFitCommissionRuleFailure.document }
    }
}
struct UFitCommissionGradeOption: UFitCommissionOption {
    static let kind = UFitCommissionOptionKind.grades
    let code: String; let label: String; let rank: Int
    var id: String { code }
    private enum CodingKeys: String, CodingKey, CaseIterable { case code, label, rank }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCommissionRuleFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        code = try value.decode(String.self, forKey: .code); label = try value.decode(String.self, forKey: .label); rank = try value.decode(Int.self, forKey: .rank)
        guard [code, label].allSatisfy(UFitCommissionRuleContract.text) else { throw UFitCommissionRuleFailure.document }
    }
}
struct UFitCommissionOptionPageDTO<Option: UFitCommissionOption>: Decodable {
    let kind: UFitCommissionOptionKind; let items: [Option]; let nextCursor: String?
    private enum CodingKeys: String, CodingKey, CaseIterable { case kind, items, nextCursor }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCommissionRuleFailure.page)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        kind = try value.decode(UFitCommissionOptionKind.self, forKey: .kind); items = try value.decode([Option].self, forKey: .items)
        nextCursor = try value.decodeIfPresent(String.self, forKey: .nextCursor)
    }
    func validate(cursor: String?) throws {
        guard kind == Option.kind, items.count <= UFitCommissionRuleContract.pageLimit, Set(items.map(\.id)).count == items.count,
              nextCursor == nil || (items.count == UFitCommissionRuleContract.pageLimit && nextCursor == items.last?.id && nextCursor != cursor) else { throw UFitCommissionRuleFailure.page }
    }
}
