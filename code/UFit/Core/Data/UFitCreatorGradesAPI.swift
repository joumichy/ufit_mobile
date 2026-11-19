import Foundation

private enum CreatorGradesHTTP {
    static let get = "GET"; static let post = "POST"
    static let definitions = "admin/creator-grades"; static let assignments = "admin/creator-grade-assignments"
    static let separator = "/"; static let history = "/history"; static let revisions = "/revisions"; static let changes = "/changes"
    static let limit = "limit"; static let cursor = "cursor"; static let search = "search"; static let assignable = "assignable"
    static let yes = "true"; static let no = "false"
    static func page(cursor: String?, search: String = String()) throws -> [URLQueryItem] {
        let search = UFitServerTextInput.trimmed(search)
        guard search.utf16.count <= UFitCreatorGradeContract.searchLimit else { throw UFitCreatorGradeFailure.input }
        var result = [URLQueryItem(name: limit, value: String(UFitCreatorGradeContract.pageLimit))]
        if let cursor { result.append(URLQueryItem(name: Self.cursor, value: cursor)) }
        if !search.isEmpty { result.append(URLQueryItem(name: Self.search, value: search)) }
        return result
    }
}

extension UFitAPIClient {
    func fetchCreatorGrades(cursor: String? = nil, search: String = String(), assignable: Bool? = nil) async throws -> UFitCreatorGradePageDTO<UFitCreatorGradeDTO> {
        guard cursor == nil || UFitCreatorGradeContract.code(cursor!) else { throw UFitCreatorGradeFailure.input }
        var query = try CreatorGradesHTTP.page(cursor: cursor, search: search)
        if let assignable { query.append(URLQueryItem(name: CreatorGradesHTTP.assignable, value: assignable ? CreatorGradesHTTP.yes : CreatorGradesHTTP.no)) }
        let result: UFitCreatorGradePageDTO<UFitCreatorGradeDTO> = try await send(CreatorGradesHTTP.get, path: CreatorGradesHTTP.definitions, query: query, requiresAuth: true)
        try result.validate(cursor: cursor)
        guard assignable == nil || result.items.allSatisfy({ $0.assignable == assignable }),
              zip(result.items, result.items.dropFirst()).allSatisfy({ $0.code < $1.code }),
              cursor == nil || result.items.allSatisfy({ $0.code > cursor! }) else { throw UFitCreatorGradeFailure.page }
        return result
    }
    func fetchCreatorGrade(code: String) async throws -> UFitCreatorGradeDTO {
        guard UFitCreatorGradeContract.code(code) else { throw UFitCreatorGradeFailure.input }
        let result: UFitCreatorGradeDTO = try await send(CreatorGradesHTTP.get, path: CreatorGradesHTTP.definitions + CreatorGradesHTTP.separator + code, requiresAuth: true)
        guard result.code == code else { throw UFitCreatorGradeFailure.document }; return result
    }
    func fetchCreatorGradeHistory(code: String, cursor: String? = nil) async throws -> UFitCreatorGradePageDTO<UFitCreatorGradeRevisionDTO> {
        guard UFitCreatorGradeContract.code(code), cursor == nil || UFitCreatorGradeContract.identifier(cursor!) else { throw UFitCreatorGradeFailure.input }
        let result: UFitCreatorGradePageDTO<UFitCreatorGradeRevisionDTO> = try await send(CreatorGradesHTTP.get,
            path: CreatorGradesHTTP.definitions + CreatorGradesHTTP.separator + code + CreatorGradesHTTP.history, query: CreatorGradesHTTP.page(cursor: cursor), requiresAuth: true)
        try result.validate(cursor: cursor)
        guard result.items.allSatisfy({ $0.code == code }), Set(result.items.map(\.version)).count == result.items.count,
              zip(result.items, result.items.dropFirst()).allSatisfy({ $0.version == $1.version + UFitCreatorGradeContract.versionStep && $0.previousRevisionId == $1.id }) else { throw UFitCreatorGradeFailure.page }
        return result
    }
    func createCreatorGrade(code: String, configuration: UFitCreatorGradeConfiguration) async throws -> UFitCreatorGradeDTO {
        guard UFitCreatorGradeContract.code(code), code != UFitCreatorGradeContract.initialCode else { throw UFitCreatorGradeFailure.input }
        try configuration.validate()
        let result: UFitCreatorGradeDTO = try await send(CreatorGradesHTTP.post, path: CreatorGradesHTTP.definitions,
            body: CreatorGradeCreation(code: code, configuration: configuration), requiresAuth: true, publicOutfitsChange: false)
        guard result.code == code, result.matches(configuration), result.version == UFitCreatorGradeContract.initialVersion,
              result.updatedAt != nil, result.assignedCreators == .zero else { throw UFitCreatorGradeFailure.document }; return result
    }
    func reviseCreatorGrade(_ current: UFitCreatorGradeDTO, configuration: UFitCreatorGradeConfiguration) async throws -> UFitCreatorGradeDTO {
        try configuration.validate()
        guard current.version < UFitCreatorGradeContract.maximumInteger, !current.isInitial || configuration.assignable else { throw UFitCreatorGradeFailure.input }
        let result: UFitCreatorGradeDTO = try await send(CreatorGradesHTTP.post, path: CreatorGradesHTTP.definitions + CreatorGradesHTTP.separator + current.code + CreatorGradesHTTP.revisions,
            body: CreatorGradeRevision(expectedVersion: current.version, configuration: configuration), requiresAuth: true, publicOutfitsChange: false)
        guard result.code == current.code, result.matches(configuration), result.version == current.version + UFitCreatorGradeContract.versionStep,
              result.revisionId != current.revisionId else { throw UFitCreatorGradeFailure.document }; return result
    }
    func fetchCreatorGradeAssignments(cursor: String? = nil, search: String = String()) async throws -> UFitCreatorGradePageDTO<UFitCreatorGradeAssignmentDTO> {
        guard cursor == nil || UFitCreatorGradeContract.identifier(cursor!) else { throw UFitCreatorGradeFailure.input }
        let result: UFitCreatorGradePageDTO<UFitCreatorGradeAssignmentDTO> = try await send(CreatorGradesHTTP.get, path: CreatorGradesHTTP.assignments,
            query: CreatorGradesHTTP.page(cursor: cursor, search: search), requiresAuth: true)
        try result.validate(cursor: cursor); return result
    }
    func fetchCreatorGradeAssignment(creatorID: String) async throws -> UFitCreatorGradeAssignmentDTO {
        guard UFitCreatorGradeContract.identifier(creatorID) else { throw UFitCreatorGradeFailure.input }
        let result: UFitCreatorGradeAssignmentDTO = try await send(CreatorGradesHTTP.get, path: CreatorGradesHTTP.assignments + CreatorGradesHTTP.separator + creatorID, requiresAuth: true)
        guard result.creatorId == creatorID else { throw UFitCreatorGradeFailure.document }; return result
    }
    func fetchCreatorGradeAssignmentHistory(creatorID: String, cursor: String? = nil) async throws -> UFitCreatorGradePageDTO<UFitCreatorGradeChangeDTO> {
        guard UFitCreatorGradeContract.identifier(creatorID), cursor == nil || UFitCreatorGradeContract.identifier(cursor!) else { throw UFitCreatorGradeFailure.input }
        let result: UFitCreatorGradePageDTO<UFitCreatorGradeChangeDTO> = try await send(CreatorGradesHTTP.get,
            path: CreatorGradesHTTP.assignments + CreatorGradesHTTP.separator + creatorID + CreatorGradesHTTP.history, query: CreatorGradesHTTP.page(cursor: cursor), requiresAuth: true)
        try result.validate(cursor: cursor)
        guard result.items.allSatisfy({ $0.creatorId == creatorID }) else { throw UFitCreatorGradeFailure.page }; return result
    }
    func changeCreatorGrade(_ current: UFitCreatorGradeAssignmentDTO, gradeCode: String, reason: String, actorID: String) async throws -> UFitCreatorGradeChangeResultDTO {
        guard UFitCreatorGradeContract.code(gradeCode), gradeCode != current.gradeCode, UFitCreatorGradeContract.identifier(actorID),
              current.version < UFitCreatorGradeContract.maximumInteger, UFitCreatorGradeContract.text(reason, maximum: UFitCreatorGradeContract.reasonLimit) else { throw UFitCreatorGradeFailure.input }
        let result: UFitCreatorGradeChangeResultDTO = try await send(CreatorGradesHTTP.post,
            path: CreatorGradesHTTP.assignments + CreatorGradesHTTP.separator + current.creatorId + CreatorGradesHTTP.changes,
            body: CreatorGradeChange(gradeCode: gradeCode, expectedVersion: current.version, reason: reason), requiresAuth: true, publicOutfitsChange: false)
        guard result.assignment.creatorId == current.creatorId, result.assignment.gradeCode == gradeCode,
              result.assignment.version == current.version + UFitCreatorGradeContract.versionStep, result.change.fromGradeCode == current.gradeCode,
              result.change.source == .administration, result.change.changedByUserId == actorID, result.change.reason == reason else { throw UFitCreatorGradeFailure.document }; return result
    }
}

private struct CreatorGradeCreation: Encodable {
    let code: String; let configuration: UFitCreatorGradeConfiguration
    private enum CodingKeys: String, CodingKey { case code }
    func encode(to encoder: Encoder) throws {
        try configuration.encode(to: encoder)
        var value = encoder.container(keyedBy: CodingKeys.self); try value.encode(code, forKey: .code)
    }
}
private struct CreatorGradeRevision: Encodable {
    let expectedVersion: Int; let configuration: UFitCreatorGradeConfiguration
    private enum CodingKeys: String, CodingKey { case expectedVersion }
    func encode(to encoder: Encoder) throws {
        try configuration.encode(to: encoder)
        var value = encoder.container(keyedBy: CodingKeys.self); try value.encode(expectedVersion, forKey: .expectedVersion)
    }
}
private struct CreatorGradeChange: Encodable { let gradeCode: String; let expectedVersion: Int; let reason: String }
