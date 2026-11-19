import Foundation

struct UFitCreatorGradeAssignmentDTO: Decodable, Identifiable {
    let creatorId: String; let displayName: String; let slug: String; let creatorStatus: UFitProfileStatus; let accountStatus: UFitAccountStatus
    let gradeCode: String; let gradeLabel: String; let gradeRank: Int; let version: Int
    var id: String { creatorId }
    private enum CodingKeys: String, CodingKey, CaseIterable { case creatorId, displayName, slug, creatorStatus, accountStatus, gradeCode, gradeLabel, gradeRank, version }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCreatorGradeFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        creatorId = try value.decode(String.self, forKey: .creatorId); displayName = try value.decode(String.self, forKey: .displayName); slug = try value.decode(String.self, forKey: .slug)
        creatorStatus = try value.decode(UFitProfileStatus.self, forKey: .creatorStatus); accountStatus = try value.decode(UFitAccountStatus.self, forKey: .accountStatus)
        gradeCode = try value.decode(String.self, forKey: .gradeCode); gradeLabel = try value.decode(String.self, forKey: .gradeLabel)
        gradeRank = try value.decode(Int.self, forKey: .gradeRank); version = try value.decode(Int.self, forKey: .version)
        guard UFitCreatorGradeContract.identifier(creatorId), !UFitServerTextInput.trimmed(displayName).isEmpty, !UFitServerTextInput.trimmed(slug).isEmpty,
              UFitCreatorGradeContract.code(gradeCode),
              UFitCreatorGradeContract.text(gradeLabel, maximum: UFitCreatorGradeContract.labelLimit), UFitCreatorGradeContract.integer(gradeRank), UFitCreatorGradeContract.version(version) else { throw UFitCreatorGradeFailure.document }
    }
}

enum UFitCreatorGradeChangeSource: String, Decodable { case application, administration }

struct UFitCreatorGradeChangeDTO: Decodable, Identifiable {
    let id: String; let creatorId: String; let version: Int?; let source: UFitCreatorGradeChangeSource?
    let fromGradeCode: String?; let fromGradeLabel: String?; let toGradeCode: String; let toGradeLabel: String?
    let changedByUserId: String?; let reason: String?; let createdAt: UFitTimestamp
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, creatorId, version, source, fromGradeCode, fromGradeLabel, toGradeCode, toGradeLabel, changedByUserId, reason, createdAt }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCreatorGradeFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        id = try value.decode(String.self, forKey: .id); creatorId = try value.decode(String.self, forKey: .creatorId)
        version = try value.decodeIfPresent(Int.self, forKey: .version); source = try value.decodeIfPresent(UFitCreatorGradeChangeSource.self, forKey: .source)
        fromGradeCode = try value.decodeIfPresent(String.self, forKey: .fromGradeCode); fromGradeLabel = try value.decodeIfPresent(String.self, forKey: .fromGradeLabel)
        toGradeCode = try value.decode(String.self, forKey: .toGradeCode); toGradeLabel = try value.decodeIfPresent(String.self, forKey: .toGradeLabel)
        changedByUserId = try value.decodeIfPresent(String.self, forKey: .changedByUserId); reason = try value.decodeIfPresent(String.self, forKey: .reason)
        createdAt = try value.decode(UFitTimestamp.self, forKey: .createdAt)
        guard ([id, creatorId] + [changedByUserId].compactMap { $0 }).allSatisfy(UFitCreatorGradeContract.identifier),
              ([toGradeCode] + [fromGradeCode].compactMap { $0 }).allSatisfy(UFitCreatorGradeContract.code), (version == nil) == (source == nil) else { throw UFitCreatorGradeFailure.document }
        switch source {
        case nil:
            guard fromGradeLabel == nil, toGradeLabel == nil else { throw UFitCreatorGradeFailure.document }
        case .application:
            guard version == UFitCreatorGradeContract.initialVersion, fromGradeCode == nil, fromGradeLabel == nil,
                  let toGradeLabel, UFitCreatorGradeContract.text(toGradeLabel, maximum: UFitCreatorGradeContract.labelLimit),
                  let reason, UFitCreatorGradeContract.text(reason, maximum: UFitCreatorGradeContract.reasonLimit) else { throw UFitCreatorGradeFailure.document }
        case .administration:
            guard let version, UFitCreatorGradeContract.version(version), version > UFitCreatorGradeContract.initialVersion,
                  let fromGradeCode, fromGradeCode != toGradeCode, let fromGradeLabel, let toGradeLabel,
                  [fromGradeLabel, toGradeLabel].allSatisfy({ UFitCreatorGradeContract.text($0, maximum: UFitCreatorGradeContract.labelLimit) }),
                  changedByUserId != nil, let reason, UFitCreatorGradeContract.text(reason, maximum: UFitCreatorGradeContract.reasonLimit) else { throw UFitCreatorGradeFailure.document }
        }
    }
}

struct UFitCreatorGradeChangeResultDTO: Decodable {
    let assignment: UFitCreatorGradeAssignmentDTO; let change: UFitCreatorGradeChangeDTO
    private enum CodingKeys: String, CodingKey, CaseIterable { case assignment, change }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitCreatorGradeFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        assignment = try value.decode(UFitCreatorGradeAssignmentDTO.self, forKey: .assignment); change = try value.decode(UFitCreatorGradeChangeDTO.self, forKey: .change)
        guard assignment.creatorId == change.creatorId, assignment.version == change.version,
              assignment.gradeCode == change.toGradeCode, assignment.gradeLabel == change.toGradeLabel else { throw UFitCreatorGradeFailure.document }
    }
}
