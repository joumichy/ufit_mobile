import Foundation

enum UFitAdministeredProfileKind: String, Decodable, CaseIterable, Identifiable {
    case creator, brand
    var id: String { rawValue }
    var title: String { self == .creator ? UFitProfileAdministrationCopy.creators : UFitProfileAdministrationCopy.brands }
    var profileLabel: String { self == .creator ? UFitProfileAdministrationCopy.creators : UFitProfileAdministrationCopy.brand }
}
struct UFitProfileAdministrationActions: Decodable {
    let suspend: Bool; let activate: Bool; let pause: Bool
    private enum CodingKeys: String, CodingKey, CaseIterable { case suspend, activate, pause }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitUserAdministrationFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        suspend = try value.decode(Bool.self, forKey: .suspend)
        activate = try value.decode(Bool.self, forKey: .activate)
        pause = try value.decode(Bool.self, forKey: .pause)
    }
}
struct UFitAdministeredProfileDTO: Decodable, Identifiable {
    let id: String; let kind: UFitAdministeredProfileKind; let name: String; let slug: String
    let status: UFitProfileStatus; let version: Int; let createdAt: UFitTimestamp; let updatedAt: UFitTimestamp
    let actions: UFitProfileAdministrationActions
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, kind, name, slug, status, version, createdAt, updatedAt, actions }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitUserAdministrationFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        id = try value.decode(String.self, forKey: .id); kind = try value.decode(UFitAdministeredProfileKind.self, forKey: .kind)
        name = try value.decode(String.self, forKey: .name); slug = try value.decode(String.self, forKey: .slug)
        status = try value.decode(UFitProfileStatus.self, forKey: .status); version = try value.decode(Int.self, forKey: .version)
        createdAt = try value.decode(UFitTimestamp.self, forKey: .createdAt); updatedAt = try value.decode(UFitTimestamp.self, forKey: .updatedAt)
        actions = try value.decode(UFitProfileAdministrationActions.self, forKey: .actions)
        let immutable = status == .draft || version == UFitUserAdministrationContract.maximumVersion
        guard UFitUserAdministrationContract.identifier(id), UFitUserAdministrationContract.version(version),
              !UFitServerTextInput.trimmed(name).isEmpty, !UFitServerTextInput.trimmed(slug).isEmpty, updatedAt.value >= createdAt.value,
              !immutable || (!actions.suspend && !actions.activate && !actions.pause),
              !actions.suspend || status != .suspended, !actions.activate || status != .active, !actions.pause || status != .paused else {
            throw UFitUserAdministrationFailure.document
        }
    }
    func allows(_ status: UFitProfileStatus) -> Bool {
        switch status { case .active: actions.activate; case .paused: actions.pause; case .suspended: actions.suspend; case .draft: false }
    }
}
struct UFitProfileStatusChangeDTO: Decodable, Identifiable {
    let id: String; let profileId: String; let kind: UFitAdministeredProfileKind; let version: Int
    let fromStatus: UFitProfileStatus; let toStatus: UFitProfileStatus; let decidedByUserId: String; let reason: String; let createdAt: UFitTimestamp
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, profileId, kind, version, fromStatus, toStatus, decidedByUserId, reason, createdAt }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitUserAdministrationFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        id = try value.decode(String.self, forKey: .id); profileId = try value.decode(String.self, forKey: .profileId)
        kind = try value.decode(UFitAdministeredProfileKind.self, forKey: .kind); version = try value.decode(Int.self, forKey: .version)
        fromStatus = try value.decode(UFitProfileStatus.self, forKey: .fromStatus); toStatus = try value.decode(UFitProfileStatus.self, forKey: .toStatus)
        decidedByUserId = try value.decode(String.self, forKey: .decidedByUserId); reason = try value.decode(String.self, forKey: .reason)
        createdAt = try value.decode(UFitTimestamp.self, forKey: .createdAt)
        guard [id, profileId, decidedByUserId].allSatisfy(UFitUserAdministrationContract.identifier),
              UFitUserAdministrationContract.version(version), version > UFitUserAdministrationContract.initialVersion,
              fromStatus != toStatus, toStatus != .draft, UFitUserAdministrationContract.reason(reason) else { throw UFitUserAdministrationFailure.document }
    }
}
