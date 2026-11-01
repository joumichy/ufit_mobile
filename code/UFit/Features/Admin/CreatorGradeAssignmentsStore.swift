import Foundation
import Observation

@MainActor @Observable
final class UFitCreatorGradeAssignmentsStore {
    var search = String()
    private(set) var assignments = [UFitCreatorGradeAssignmentDTO]()
    private(set) var isLoading = false
    private(set) var openingIDs = Set<String>()
    private(set) var message: String?
    private(set) var nextCursor: String?
    @ObservationIgnored let session: UFitSessionStore
    @ObservationIgnored private let ownerID: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var navigationRequest = UUID()
    @ObservationIgnored private var appliedSearch = String()
    @ObservationIgnored private var loadingSearch: String?
    init(session: UFitSessionStore) { self.session = session; ownerID = session.user?.id }
    var isCurrentAccount: Bool { ownerID != nil && ownerID == session.user?.id && session.user?.canAdminister == true && session.user?.status == UFitCreatorGradeContract.activeAccount }
    func cancelLoading() { generation = UUID(); navigationRequest = UUID(); isLoading = false; loadingSearch = nil; openingIDs = [] }
    func load(refresh: Bool = true) async {
        let query = refresh ? search : appliedSearch
        if isLoading && refresh && loadingSearch != query { cancelLoading() }
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : nextCursor
        isLoading = true; loadingSearch = query; message = nil
        if refresh && query != appliedSearch { assignments = []; nextCursor = nil }
        defer { if generation == request { isLoading = false; loadingSearch = nil } }
        do {
            let page = try await session.api.fetchCreatorGradeAssignments(cursor: cursor, search: query)
            guard generation == request, isCurrentAccount, query == search else { return }
            let merged = refresh ? page.items : assignments + page.items
            guard Set(merged.map(\.id)).count == merged.count else { throw UFitCreatorGradeFailure.page }
            assignments = merged; nextCursor = page.nextCursor; appliedSearch = query
        } catch {
            guard generation == request, isCurrentAccount, query == search else { return }
            if UFitCreatorGradeAdminFailure.revoked(error) { assignments = []; nextCursor = nil }
            message = UFitCreatorGradeAdminFailure.message(error)
        }
    }
    func open(_ creatorID: String) async -> UFitCreatorGradeAssignmentDetailStore? {
        guard isCurrentAccount, assignments.contains(where: { $0.creatorId == creatorID }), !openingIDs.contains(creatorID) else { return nil }
        let request = generation, navigation = UUID(); navigationRequest = navigation
        openingIDs.insert(creatorID); message = nil
        defer { if generation == request { openingIDs.remove(creatorID) } }
        do {
            let assignment = try await session.api.fetchCreatorGradeAssignment(creatorID: creatorID)
            guard generation == request, navigationRequest == navigation, isCurrentAccount else { return nil }
            return UFitCreatorGradeAssignmentDetailStore(assignment: assignment, collection: self)
        } catch {
            if generation == request && navigationRequest == navigation && isCurrentAccount { message = UFitCreatorGradeAdminFailure.message(error) }
            return nil
        }
    }
}

@MainActor @Observable
final class UFitCreatorGradeAssignmentDetailStore {
    private(set) var assignment: UFitCreatorGradeAssignmentDTO
    private(set) var history = [UFitCreatorGradeChangeDTO]()
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var nextCursor: String?
    let collection: UFitCreatorGradeAssignmentsStore
    @ObservationIgnored private var generation = UUID()
    init(assignment: UFitCreatorGradeAssignmentDTO, collection: UFitCreatorGradeAssignmentsStore) { self.assignment = assignment; self.collection = collection }
    var isCurrentAccount: Bool { collection.isCurrentAccount }
    var canChangeGrade: Bool { assignment.accountStatus == .active && (assignment.creatorStatus == .active || assignment.creatorStatus == .paused) }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func receive(_ assignment: UFitCreatorGradeAssignmentDTO) throws {
        guard assignment.creatorId == self.assignment.creatorId else { throw UFitCreatorGradeFailure.document }
        self.assignment = assignment; history = []; nextCursor = nil
    }
    func load(refresh: Bool = true) async {
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : nextCursor
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let current: UFitCreatorGradeAssignmentDTO, page: UFitCreatorGradePageDTO<UFitCreatorGradeChangeDTO>
            if refresh {
                async let fetched = collection.session.api.fetchCreatorGradeAssignment(creatorID: assignment.creatorId)
                async let fetchedHistory = collection.session.api.fetchCreatorGradeAssignmentHistory(creatorID: assignment.creatorId)
                (current, page) = try await (fetched, fetchedHistory)
            } else { current = assignment; page = try await collection.session.api.fetchCreatorGradeAssignmentHistory(creatorID: assignment.creatorId, cursor: cursor) }
            guard generation == request, isCurrentAccount else { return }
            let merged = refresh ? page.items : history + page.items
            let knownVersions = merged.compactMap(\.version)
            guard Set(merged.map(\.id)).count == merged.count, Set(knownVersions).count == knownVersions.count else { throw UFitCreatorGradeFailure.page }
            assignment = current; history = merged; nextCursor = page.nextCursor
        } catch { if generation == request && isCurrentAccount { message = UFitCreatorGradeAdminFailure.message(error) } }
    }
}
