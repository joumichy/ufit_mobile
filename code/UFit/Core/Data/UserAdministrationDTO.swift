import Foundation

enum UFitUserAdministrationFailure: LocalizedError {
    case document, page, input
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "Les informations du compte reçues sont incohérentes. Actualisez avant de continuer.")
        case .page: String(localized: "La liste des comptes a changé. Actualisez pour continuer.")
        case .input: String(localized: "Vérifiez la décision et son motif.")
        }
    }
}

enum UFitUserAdministrationContract {
    static let initialVersion = 1
    static let versionStep = 1
    static let maximumVersion = 2_147_483_647
    static let pageLimit = 20
    static let searchLimit = 100
    static let reasonLimit = 500
    static func identifier(_ value: String) -> Bool { UUID(uuidString: value) != nil && value == value.lowercased() }
    static func version(_ value: Int) -> Bool { (initialVersion...maximumVersion).contains(value) }
    static func reason(_ value: String) -> Bool {
        value == UFitServerTextInput.trimmed(value) && UFitServerTextInput.valid(value, maximum: reasonLimit)
    }
}

struct UFitUserAdministrationActions: Decodable, Equatable {
    let suspend: Bool
    let activate: Bool
    let grantAdmin: Bool
    let revokeAdmin: Bool
    private enum CodingKeys: String, CodingKey, CaseIterable { case suspend, activate, grantAdmin, revokeAdmin }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitUserAdministrationFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        suspend = try value.decode(Bool.self, forKey: .suspend)
        activate = try value.decode(Bool.self, forKey: .activate)
        grantAdmin = try value.decode(Bool.self, forKey: .grantAdmin)
        revokeAdmin = try value.decode(Bool.self, forKey: .revokeAdmin)
    }
}

struct UFitAdministeredUserDTO: Decodable, Identifiable {
    let id: String
    let email: String
    let displayName: String?
    let status: UFitAccountStatus
    let roles: [UFitUserRole]
    let version: Int
    let createdAt: UFitTimestamp
    let updatedAt: UFitTimestamp
    let actions: UFitUserAdministrationActions
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, email, displayName, status, roles, version, createdAt, updatedAt, actions }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitUserAdministrationFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        id = try value.decode(String.self, forKey: .id)
        email = try value.decode(String.self, forKey: .email)
        displayName = try value.decodeIfPresent(String.self, forKey: .displayName)
        status = try value.decode(UFitAccountStatus.self, forKey: .status)
        roles = try value.decode([UFitUserRole].self, forKey: .roles)
        version = try value.decode(Int.self, forKey: .version)
        createdAt = try value.decode(UFitTimestamp.self, forKey: .createdAt)
        updatedAt = try value.decode(UFitTimestamp.self, forKey: .updatedAt)
        actions = try value.decode(UFitUserAdministrationActions.self, forKey: .actions)
        let administrator = roles.contains(.admin), superAdministrator = roles.contains(.superAdmin)
        let immutable = status == .deleted || version == UFitUserAdministrationContract.maximumVersion
        guard UFitUserAdministrationContract.identifier(id), !UFitServerTextInput.trimmed(email).isEmpty,
              Set(roles.map(\.rawValue)).count == roles.count, UFitUserAdministrationContract.version(version),
              updatedAt.value >= createdAt.value,
              !immutable || (!actions.suspend && !actions.activate && !actions.grantAdmin && !actions.revokeAdmin),
              !actions.suspend || status != .suspended, !actions.activate || status != .active,
              !actions.grantAdmin || (status == .active && !administrator && !superAdministrator),
              !actions.revokeAdmin || (administrator && !superAdministrator) else { throw UFitUserAdministrationFailure.document }
    }
    var roleCodes: Set<String> { Set(roles.map(\.rawValue)) }
}

enum UFitUserAccessChangeKind: String, Decodable { case status, adminAccess = "admin_access" }

struct UFitUserAccessChangeDTO: Decodable, Identifiable {
    let id: String
    let userId: String
    let version: Int
    let kind: UFitUserAccessChangeKind
    let fromStatus: UFitAccountStatus
    let toStatus: UFitAccountStatus
    let adminBefore: Bool
    let adminAfter: Bool
    let decidedByUserId: String
    let reason: String
    let createdAt: UFitTimestamp
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, userId, version, kind, fromStatus, toStatus, adminBefore, adminAfter, decidedByUserId, reason, createdAt }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitUserAdministrationFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        id = try value.decode(String.self, forKey: .id)
        userId = try value.decode(String.self, forKey: .userId)
        version = try value.decode(Int.self, forKey: .version)
        kind = try value.decode(UFitUserAccessChangeKind.self, forKey: .kind)
        fromStatus = try value.decode(UFitAccountStatus.self, forKey: .fromStatus)
        toStatus = try value.decode(UFitAccountStatus.self, forKey: .toStatus)
        adminBefore = try value.decode(Bool.self, forKey: .adminBefore)
        adminAfter = try value.decode(Bool.self, forKey: .adminAfter)
        decidedByUserId = try value.decode(String.self, forKey: .decidedByUserId)
        reason = try value.decode(String.self, forKey: .reason)
        createdAt = try value.decode(UFitTimestamp.self, forKey: .createdAt)
        guard [id, userId, decidedByUserId].allSatisfy(UFitUserAdministrationContract.identifier),
              UFitUserAdministrationContract.version(version), version > UFitUserAdministrationContract.initialVersion,
              fromStatus != .deleted, toStatus != .deleted, UFitUserAdministrationContract.reason(reason) else { throw UFitUserAdministrationFailure.document }
        switch kind {
        case .status:
            guard fromStatus != toStatus, toStatus == .active || toStatus == .suspended, adminBefore == adminAfter else { throw UFitUserAdministrationFailure.document }
        case .adminAccess:
            guard fromStatus == toStatus, adminBefore != adminAfter, !adminAfter || toStatus == .active else { throw UFitUserAdministrationFailure.document }
        }
    }
}

struct UFitUserAdministrationPageDTO<Item: Decodable & Identifiable>: Decodable where Item.ID == String {
    let items: [Item]
    let nextCursor: String?
    private enum CodingKeys: String, CodingKey, CaseIterable { case items, nextCursor }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitUserAdministrationFailure.page)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        items = try value.decode([Item].self, forKey: .items)
        nextCursor = try value.decodeIfPresent(String.self, forKey: .nextCursor)
    }
    func validate(cursor: String?) throws {
        guard items.count <= UFitUserAdministrationContract.pageLimit, Set(items.map(\.id)).count == items.count,
              items.allSatisfy({ $0.id != cursor }),
              nextCursor == nil || (UFitUserAdministrationContract.identifier(nextCursor!) && items.count == UFitUserAdministrationContract.pageLimit && nextCursor == items.last?.id) else { throw UFitUserAdministrationFailure.page }
    }
}
