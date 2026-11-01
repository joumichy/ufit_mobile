import Foundation
import Observation

@MainActor @Observable
final class UFitCreatorGradesStore {
    var search = String()
    private(set) var assignable: Bool?
    private(set) var grades = [UFitCreatorGradeDTO]()
    private(set) var rows = [UFitCreatorGradeRow]()
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
    func filter(assignable: Bool?) async {
        cancelLoading(); self.assignable = assignable; grades = []; rows = []; nextCursor = nil
        await load()
    }
    func load(refresh: Bool = true) async {
        let query = refresh ? search : appliedSearch
        if isLoading && refresh && loadingSearch != query { cancelLoading() }
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : nextCursor
        isLoading = true; loadingSearch = query; message = nil
        if refresh && query != appliedSearch { grades = []; rows = []; nextCursor = nil }
        defer { if generation == request { isLoading = false; loadingSearch = nil } }
        do {
            let result = try await session.api.fetchCreatorGrades(cursor: cursor, search: query, assignable: assignable)
            guard generation == request, isCurrentAccount, query == search else { return }
            let merged = refresh ? result.items : grades + result.items
            guard Set(merged.map(\.id)).count == merged.count, zip(merged, merged.dropFirst()).allSatisfy({ $0.code < $1.code }) else { throw UFitCreatorGradeFailure.page }
            grades = merged; rows = merged.map(\.row); nextCursor = result.nextCursor; appliedSearch = query
        } catch {
            guard generation == request, isCurrentAccount, query == search else { return }
            if UFitCreatorGradeAdminFailure.revoked(error) { grades = []; rows = []; nextCursor = nil }
            message = UFitCreatorGradeAdminFailure.message(error)
        }
    }
    func open(_ code: String) async -> UFitCreatorGradeDetailStore? {
        guard isCurrentAccount, grades.contains(where: { $0.code == code }), !openingIDs.contains(code) else { return nil }
        let request = generation, navigation = UUID(); navigationRequest = navigation
        openingIDs.insert(code); message = nil
        defer { if generation == request { openingIDs.remove(code) } }
        do {
            let grade = try await session.api.fetchCreatorGrade(code: code)
            guard generation == request, navigationRequest == navigation, isCurrentAccount else { return nil }
            return UFitCreatorGradeDetailStore(grade: grade, collection: self)
        } catch {
            if generation == request && navigationRequest == navigation && isCurrentAccount { message = UFitCreatorGradeAdminFailure.message(error) }
            return nil
        }
    }
    func report(_ error: Error) { message = UFitCreatorGradeAdminFailure.message(error) }
}

@MainActor @Observable
final class UFitCreatorGradeDetailStore {
    private(set) var grade: UFitCreatorGradeDTO
    private(set) var history = [UFitCreatorGradeRevisionRow]()
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var nextCursor: String?
    let collection: UFitCreatorGradesStore
    @ObservationIgnored private var revisions = [UFitCreatorGradeRevisionDTO]()
    @ObservationIgnored private var generation = UUID()
    init(grade: UFitCreatorGradeDTO, collection: UFitCreatorGradesStore) { self.grade = grade; self.collection = collection }
    var isCurrentAccount: Bool { collection.isCurrentAccount }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func receive(_ grade: UFitCreatorGradeDTO) throws {
        guard grade.code == self.grade.code else { throw UFitCreatorGradeFailure.document }
        self.grade = grade; history = []; revisions = []; nextCursor = nil
    }
    func load(refresh: Bool = true) async {
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : nextCursor
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let current: UFitCreatorGradeDTO, page: UFitCreatorGradePageDTO<UFitCreatorGradeRevisionDTO>
            if refresh {
                async let fetched = collection.session.api.fetchCreatorGrade(code: grade.code)
                async let fetchedHistory = collection.session.api.fetchCreatorGradeHistory(code: grade.code)
                (current, page) = try await (fetched, fetchedHistory)
                guard page.items.first?.id == current.revisionId else { throw UFitCreatorGradeFailure.page }
            } else { current = grade; page = try await collection.session.api.fetchCreatorGradeHistory(code: grade.code, cursor: cursor) }
            guard generation == request, isCurrentAccount else { return }
            let merged = refresh ? page.items : revisions + page.items
            guard Set(merged.map(\.id)).count == merged.count,
                  zip(merged, merged.dropFirst()).allSatisfy({ $0.version == $1.version + UFitCreatorGradeContract.versionStep && $0.previousRevisionId == $1.id }) else { throw UFitCreatorGradeFailure.page }
            grade = current; revisions = merged; history = merged.map { $0.row(currentID: current.revisionId) }; nextCursor = page.nextCursor
        } catch { if generation == request && isCurrentAccount { message = UFitCreatorGradeAdminFailure.message(error) } }
    }
}
