import Foundation

enum UFitCreatorGradeFailure: LocalizedError {
    case document, page, input
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "Les grades reçus sont incohérents. Actualisez avant de continuer.")
        case .page: String(localized: "La liste a changé. Actualisez pour continuer.")
        case .input: String(localized: "Vérifiez le grade et le motif de cette modification.")
        }
    }
}

enum UFitCreatorGradeContract {
    static let initialCode = "seed"
    static let initialVersion = 1; static let versionStep = 1; static let maximumInteger = 2_147_483_647
    static let pageLimit = 20; static let codeLimit = 80; static let labelLimit = 120; static let reasonLimit = 500; static let searchLimit = 100
    static let maximumCount = 9_007_199_254_740_991
    static let codePattern = #"^[a-z][a-z0-9-]*$"#
    static let activeAccount = UFitAccountStatus.active.rawValue
    static func identifier(_ value: String) -> Bool { UUID(uuidString: value) != nil }
    static func code(_ value: String) -> Bool { value == UFitServerTextInput.trimmed(value) && value.utf16.count <= codeLimit && value.range(of: codePattern, options: .regularExpression) != nil }
    static func integer(_ value: Int) -> Bool { (.zero...maximumInteger).contains(value) }
    static func version(_ value: Int) -> Bool { (initialVersion...maximumInteger).contains(value) }
    static func text(_ value: String, maximum: Int) -> Bool { value == UFitServerTextInput.trimmed(value) && UFitServerTextInput.valid(value, maximum: maximum) }
}

struct UFitCreatorGradeDTO: Decodable, Identifiable {
    let code: String; let label: String; let rank: Int; let assignable: Bool; let isInitial: Bool
    let version: Int; let revisionId: String; let assignedCreators: Int
    let createdAt: UFitTimestamp; let updatedAt: UFitTimestamp?
    var id: String { code }
    private enum CodingKeys: String, CodingKey, CaseIterable { case code, label, rank, assignable, isInitial, version, revisionId, assignedCreators, createdAt, updatedAt }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCreatorGradeFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        code = try value.decode(String.self, forKey: .code); label = try value.decode(String.self, forKey: .label)
        rank = try value.decode(Int.self, forKey: .rank); assignable = try value.decode(Bool.self, forKey: .assignable)
        isInitial = try value.decode(Bool.self, forKey: .isInitial); version = try value.decode(Int.self, forKey: .version)
        revisionId = try value.decode(String.self, forKey: .revisionId); assignedCreators = try value.decode(Int.self, forKey: .assignedCreators)
        createdAt = try value.decode(UFitTimestamp.self, forKey: .createdAt); updatedAt = try value.decodeIfPresent(UFitTimestamp.self, forKey: .updatedAt)
        guard UFitCreatorGradeContract.code(code), UFitCreatorGradeContract.text(label, maximum: UFitCreatorGradeContract.labelLimit),
              UFitCreatorGradeContract.integer(rank), UFitCreatorGradeContract.version(version), UFitCreatorGradeContract.identifier(revisionId), (.zero...UFitCreatorGradeContract.maximumCount).contains(assignedCreators),
              isInitial == (code == UFitCreatorGradeContract.initialCode), !isInitial || assignable,
              version == UFitCreatorGradeContract.initialVersion || updatedAt != nil,
              updatedAt == nil || updatedAt!.value >= createdAt.value else { throw UFitCreatorGradeFailure.document }
    }
    func matches(_ configuration: UFitCreatorGradeConfiguration) -> Bool {
        label == configuration.label && rank == configuration.rank && assignable == configuration.assignable
    }
}

struct UFitCreatorGradeRevisionDTO: Decodable, Identifiable {
    let id: String; let code: String; let version: Int; let previousRevisionId: String?
    let label: String; let rank: Int; let assignable: Bool
    let changedByUserId: String?; let reason: String?; let recordedAt: UFitTimestamp
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, code, version, previousRevisionId, label, rank, assignable, changedByUserId, reason, recordedAt }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCreatorGradeFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        id = try value.decode(String.self, forKey: .id); code = try value.decode(String.self, forKey: .code)
        version = try value.decode(Int.self, forKey: .version); previousRevisionId = try value.decodeIfPresent(String.self, forKey: .previousRevisionId)
        label = try value.decode(String.self, forKey: .label); rank = try value.decode(Int.self, forKey: .rank); assignable = try value.decode(Bool.self, forKey: .assignable)
        changedByUserId = try value.decodeIfPresent(String.self, forKey: .changedByUserId); reason = try value.decodeIfPresent(String.self, forKey: .reason)
        recordedAt = try value.decode(UFitTimestamp.self, forKey: .recordedAt)
        guard ([id] + [previousRevisionId, changedByUserId].compactMap { $0 }).allSatisfy(UFitCreatorGradeContract.identifier),
              UFitCreatorGradeContract.code(code), UFitCreatorGradeContract.text(label, maximum: UFitCreatorGradeContract.labelLimit), UFitCreatorGradeContract.integer(rank), UFitCreatorGradeContract.version(version),
              (version == UFitCreatorGradeContract.initialVersion) == (previousRevisionId == nil), previousRevisionId != id,
              (changedByUserId == nil) == (reason == nil), version == UFitCreatorGradeContract.initialVersion || changedByUserId != nil,
              reason == nil || UFitCreatorGradeContract.text(reason!, maximum: UFitCreatorGradeContract.reasonLimit) else { throw UFitCreatorGradeFailure.document }
    }
}

struct UFitCreatorGradePageDTO<Item: Decodable & Identifiable>: Decodable where Item.ID == String {
    let items: [Item]; let nextCursor: String?
    private enum CodingKeys: String, CodingKey, CaseIterable { case items, nextCursor }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCreatorGradeFailure.page)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        items = try value.decode([Item].self, forKey: .items); nextCursor = try value.decodeIfPresent(String.self, forKey: .nextCursor)
    }
    func validate(cursor: String?) throws {
        guard items.count <= UFitCreatorGradeContract.pageLimit, Set(items.map(\.id)).count == items.count, items.allSatisfy({ $0.id != cursor }),
              nextCursor == nil || (items.count == UFitCreatorGradeContract.pageLimit && nextCursor == items.last?.id && nextCursor != cursor) else { throw UFitCreatorGradeFailure.page }
    }
}

struct UFitCreatorGradeConfiguration: Encodable {
    let label: String; let rank: Int; let assignable: Bool; let reason: String
    func validate() throws {
        guard UFitCreatorGradeContract.text(label, maximum: UFitCreatorGradeContract.labelLimit), UFitCreatorGradeContract.integer(rank),
              UFitCreatorGradeContract.text(reason, maximum: UFitCreatorGradeContract.reasonLimit) else { throw UFitCreatorGradeFailure.input }
    }
}
