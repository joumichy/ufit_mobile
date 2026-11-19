import Foundation
import Observation

@MainActor @Observable
final class UFitUserAdministrationStore {
    var search = String()
    private(set) var status: UFitAccountStatus?
    private(set) var role: UFitUserRole?
    private(set) var users = [UFitAdministeredUserDTO]()
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var accessRevoked = false
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
    var isCurrentAccount: Bool {
        !accessRevoked && ownerID != nil && ownerID == session.user?.id && session.user?.canAdminister == true && session.user?.status == UFitAccountStatus.active.rawValue
    }
    func cancelLoading() {
        generation = UUID(); navigationRequest = UUID(); isLoading = false; loadingSearch = nil; openingIDs = []
    }
    func filter(status: UFitAccountStatus?, role: UFitUserRole?) async {
        cancelLoading(); self.status = status; self.role = role
        users = []; nextCursor = nil; hasLoaded = false
        await load()
    }
    func load(refresh: Bool = true) async {
        let query = refresh ? UFitServerTextInput.trimmed(search) : appliedSearch
        if refresh && isLoading && loadingSearch != query { cancelLoading() }
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : nextCursor
        isLoading = true; loadingSearch = query; message = nil
        if refresh && query != appliedSearch { users = []; nextCursor = nil; hasLoaded = false }
        defer { if generation == request { isLoading = false; loadingSearch = nil } }
        do {
            let page = try await session.api.fetchAdministeredUsers(cursor: cursor, search: query, status: status, role: role)
            guard generation == request, isCurrentAccount, query == UFitServerTextInput.trimmed(search) else { return }
            let merged = refresh ? page.items : users + page.items
            guard Set(merged.map(\.id)).count == merged.count, zip(merged, merged.dropFirst()).allSatisfy({ $0.id < $1.id }) else { throw UFitUserAdministrationFailure.page }
            users = merged; nextCursor = page.nextCursor; hasLoaded = true; appliedSearch = query
        } catch {
            guard generation == request, isCurrentAccount, query == UFitServerTextInput.trimmed(search) else { return }
            recordReadFailure(error)
        }
    }
    func open(_ id: String) async -> UFitUserAdministrationDetailStore? {
        guard isCurrentAccount, users.contains(where: { $0.id == id }), !openingIDs.contains(id) else { return nil }
        let request = generation, navigation = UUID(); navigationRequest = navigation
        openingIDs.insert(id); message = nil
        defer { if generation == request { openingIDs.remove(id) } }
        do {
            let current = try await session.api.fetchAdministeredUser(id: id)
            guard generation == request, navigationRequest == navigation, isCurrentAccount else { return nil }
            return UFitUserAdministrationDetailStore(user: current, collection: self)
        } catch {
            if generation == request && navigationRequest == navigation && isCurrentAccount { recordReadFailure(error) }
            return nil
        }
    }
    func recordReadFailure(_ error: Error) {
        if UFitUserAdministrationError.revoked(error) {
            accessRevoked = true; users = []; nextCursor = nil; hasLoaded = false
            Task {
                guard ownerID == session.user?.id else { return }
                await session.reloadProfile()
            }
        }
        message = UFitUserAdministrationError.message(error)
    }
}

@MainActor @Observable
final class UFitUserAdministrationDetailStore {
    private(set) var user: UFitAdministeredUserDTO
    private(set) var history = [UFitUserAccessChangeDTO]()
    private(set) var isLoading = false
    private(set) var hasLoadedHistory = false
    private(set) var message: String?
    private(set) var nextCursor: String?
    let collection: UFitUserAdministrationStore
    @ObservationIgnored private var generation = UUID()

    init(user: UFitAdministeredUserDTO, collection: UFitUserAdministrationStore) { self.user = user; self.collection = collection }
    var isCurrentAccount: Bool { collection.isCurrentAccount }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func report(_ error: Error) { message = UFitUserAdministrationError.message(error) }
    func receive(_ user: UFitAdministeredUserDTO) throws {
        guard user.id == self.user.id else { throw UFitUserAdministrationFailure.document }
        self.user = user; history = []; nextCursor = nil; hasLoadedHistory = false
    }
    func load(refresh: Bool = true) async {
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : nextCursor
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let current: UFitAdministeredUserDTO, page: UFitUserAdministrationPageDTO<UFitUserAccessChangeDTO>
            if refresh {
                async let fetched = collection.session.api.fetchAdministeredUser(id: user.id)
                async let fetchedHistory = collection.session.api.fetchUserAccessHistory(userID: user.id)
                (current, page) = try await (fetched, fetchedHistory)
            } else {
                current = user
                page = try await collection.session.api.fetchUserAccessHistory(userID: user.id, cursor: cursor)
            }
            guard generation == request, isCurrentAccount else { return }
            let merged = refresh ? page.items : history + page.items
            guard merged.allSatisfy({ $0.version <= current.version }), Set(merged.map(\.id)).count == merged.count,
                  zip(merged, merged.dropFirst()).allSatisfy({ $0.version > $1.version }) else { throw UFitUserAdministrationFailure.page }
            user = current; history = merged; nextCursor = page.nextCursor; hasLoadedHistory = true
        } catch {
            guard generation == request, isCurrentAccount else { return }
            if UFitUserAdministrationError.revoked(error) {
                collection.recordReadFailure(error); history = []; nextCursor = nil; hasLoadedHistory = false
            }
            message = UFitUserAdministrationError.message(error)
        }
    }
}
