import Foundation
import Observation

@MainActor @Observable
final class UFitCommissionReferenceStore: Identifiable {
    let id = UUID()
    let kind: UFitCommissionReferenceKind
    let brandID: String?
    let selectedID: String?
    let noneTitle: String?
    var search = String()
    private(set) var rows = [UFitCommissionReference]()
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var message: String?
    private(set) var nextCursor: String?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let ownerID: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var appliedSearch = String()
    init(kind: UFitCommissionReferenceKind, brandID: String? = nil, selectedID: String?, noneTitle: String?, session: UFitSessionStore) {
        self.kind = kind; self.brandID = brandID; self.selectedID = selectedID; self.noneTitle = noneTitle; self.session = session; ownerID = session.user?.id
    }
    var isCurrentAccount: Bool { ownerID != nil && ownerID == session.user?.id && session.user?.canAdminister == true }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func canSelect(_ value: UFitCommissionReference?) -> Bool {
        isCurrentAccount && (value == nil ? noneTitle != nil : rows.contains { $0 == value })
    }
    func load(refresh: Bool = true) async {
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : nextCursor, query = refresh ? search : appliedSearch
        isLoading = true; message = nil
        if refresh && query != appliedSearch { rows = []; nextCursor = nil; hasLoaded = false }
        defer { if generation == request { isLoading = false } }
        do {
            let values: [UFitCommissionReference], next: String?
            switch kind {
            case .brand:
                let result = try await session.api.fetchCommissionBrands(cursor: cursor, search: query)
                values = result.items.map { .init(id: $0.id, title: $0.brandName, detail: $0.status.label) }; next = result.nextCursor
            case .product:
                guard let brandID else { throw UFitCommissionRuleFailure.input }
                let result = try await session.api.fetchCommissionProducts(brandID: brandID, cursor: cursor, search: query)
                values = result.items.map { .init(id: $0.id, title: $0.name, detail: $0.status.label) }; next = result.nextCursor
            case .grade:
                let result = try await session.api.fetchCommissionGrades(cursor: cursor, search: query)
                values = result.items.map { .init(id: $0.code, title: $0.label, detail: nil) }; next = result.nextCursor
            }
            guard generation == request, isCurrentAccount else { return }
            let merged = refresh ? values : rows + values
            guard Set(merged.map(\.id)).count == merged.count else { throw UFitCommissionRuleFailure.page }
            rows = merged; nextCursor = next; appliedSearch = query
            hasLoaded = true
        } catch {
            guard generation == request, isCurrentAccount else { return }
            if UFitCommissionAdminFailure.revoked(error) { rows = []; nextCursor = nil; hasLoaded = false }
            if case UFitCommissionRuleFailure.input = error { message = Copy.searchLimit }
            else { message = UFitCommissionAdminFailure.message(error) }
        }
    }
    private enum Copy { static let searchLimit = String(localized: "Limitez la recherche à 100 caractères.") }
}
