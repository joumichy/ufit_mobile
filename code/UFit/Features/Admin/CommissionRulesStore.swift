import Foundation
import Observation

@MainActor @Observable
final class UFitCommissionRulesStore {
    private(set) var rules = [UFitCommissionRuleDTO]()
    private(set) var rows = [UFitCommissionRuleRow]()
    private(set) var brand: UFitCommissionReference?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var openingIDs = Set<String>()
    private(set) var message: String?
    private(set) var nextCursor: String?
    @ObservationIgnored let session: UFitSessionStore
    @ObservationIgnored private let ownerID: String?
    @ObservationIgnored private var generation = UUID()
    init(session: UFitSessionStore) { self.session = session; ownerID = session.user?.id }
    var isCurrentAccount: Bool { ownerID != nil && ownerID == session.user?.id && session.user?.canAdminister == true }
    func cancelLoading() { generation = UUID(); isLoading = false; openingIDs = [] }
    func filter(_ brand: UFitCommissionReference?) async {
        cancelLoading(); self.brand = brand; rules = []; rows = []; nextCursor = nil; hasLoaded = false
        await load()
    }
    func load(refresh: Bool = true) async {
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : nextCursor
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await session.api.fetchCommissionRules(brandID: brand?.id, cursor: cursor)
            guard generation == request, isCurrentAccount else { return }
            let merged = refresh ? page.items : rules + page.items
            guard Set(merged.map(\.scopeId)).count == merged.count else { throw UFitCommissionRuleFailure.page }
            let rendered = try merged.map { try $0.row() }
            rules = merged; rows = rendered; nextCursor = page.nextCursor
            hasLoaded = true
        } catch {
            guard generation == request, isCurrentAccount else { return }
            if UFitCommissionAdminFailure.revoked(error) { rules = []; rows = []; nextCursor = nil; hasLoaded = false }
            message = UFitCommissionAdminFailure.message(error)
        }
    }
    func open(_ id: String) async -> UFitCommissionRuleDetailStore? {
        guard isCurrentAccount, rules.contains(where: { $0.scopeId == id }), !openingIDs.contains(id) else { return nil }
        let request = generation
        openingIDs.insert(id); message = nil
        defer { if generation == request { openingIDs.remove(id) } }
        do {
            let rule = try await session.api.fetchCommissionRule(scopeID: id)
            guard generation == request, isCurrentAccount else { return nil }
            return UFitCommissionRuleDetailStore(rule: rule, collection: self)
        } catch {
            if generation == request && isCurrentAccount { message = UFitCommissionAdminFailure.message(error) }
            return nil
        }
    }
    func report(_ error: Error) { message = UFitCommissionAdminFailure.message(error) }
}

@MainActor @Observable
final class UFitCommissionRuleDetailStore {
    private(set) var rule: UFitCommissionRuleDTO
    private(set) var document: UFitCommissionRuleDocument?
    private(set) var history = [UFitCommissionRevisionRow]()
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var nextCursor: String?
    let collection: UFitCommissionRulesStore
    @ObservationIgnored private var revisions = [UFitCommissionRuleDTO]()
    @ObservationIgnored private var generation = UUID()
    init(rule: UFitCommissionRuleDTO, collection: UFitCommissionRulesStore) { self.rule = rule; self.collection = collection }
    var isCurrentAccount: Bool { collection.isCurrentAccount }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func report(_ error: Error) { message = UFitCommissionAdminFailure.message(error) }
    func receive(_ value: UFitCommissionRuleDTO) throws {
        guard value.scopeId == rule.scopeId, value.supersededAt == nil else { throw UFitCommissionRuleFailure.document }
        document = try value.document(); rule = value; revisions = []; history = []; nextCursor = nil
    }
    func load(refresh: Bool = true) async {
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : nextCursor
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let page: UFitCommissionRulePageDTO
            let current: UFitCommissionRuleDTO
            if refresh {
                async let fetched = collection.session.api.fetchCommissionRule(scopeID: rule.scopeId)
                async let fetchedHistory = collection.session.api.fetchCommissionRuleHistory(scopeID: rule.scopeId)
                (current, page) = try await (fetched, fetchedHistory)
                guard page.items.first?.id == current.id else { throw UFitCommissionRuleFailure.document }
            } else {
                page = try await collection.session.api.fetchCommissionRuleHistory(scopeID: rule.scopeId, cursor: cursor)
                current = rule
            }
            guard generation == request, isCurrentAccount else { return }
            let merged = refresh ? page.items : revisions + page.items
            guard Set(merged.map(\.id)).count == merged.count,
                zip(merged, merged.dropFirst()).allSatisfy({ $0.revision > $1.revision }) else { throw UFitCommissionRuleFailure.page }
            let rendered = try merged.map { try $0.historyRow(currentID: current.id) }
            document = try current.document(); rule = current; revisions = merged; history = rendered; nextCursor = page.nextCursor
        } catch {
            guard generation == request, isCurrentAccount else { return }
            if UFitCommissionAdminFailure.revoked(error) { document = nil; revisions = []; history = []; nextCursor = nil }
            message = UFitCommissionAdminFailure.message(error)
        }
    }
}
