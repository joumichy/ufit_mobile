import Foundation
import Observation

@MainActor @Observable
final class UFitReturnDetailStore {
    let id: String
    let list: UFitReturnsStore
    private(set) var detail: UFitReturnDetailDTO?
    private(set) var isLoading = false
    private(set) var activeAction: UFitReturnAction?
    private(set) var isStale = false
    private(set) var message: String?
    private enum Copy {
        static let updated = String(localized: "Dossier actualisé.")
        static let changed = String(localized: "Le dossier a changé. Actualisez avant de continuer.")
    }
    init(id: String, list: UFitReturnsStore) throws {
        guard UUID(uuidString: id) != nil, list.isCurrentAccount else { throw UFitReturnContractError.document }
        self.id = id; self.list = list
    }
    var isCurrentAccount: Bool { list.isCurrentAccount }
    var presentation: UFitReturnDetailPresentation? { detail?.presentation(stale: isStale) }
    func load() async {
        guard !isLoading, activeAction == nil, isCurrentAccount else { return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            let result = try await list.session.api.fetchReturn(scope: list.scope, id: id)
            guard isCurrentAccount else { return }; receive(result)
        } catch { recordFailure(error) }
    }
    func perform(_ command: UFitReturnCommand, draft: UFitReturnActionDraft? = nil) async -> Bool {
        guard !isLoading, activeAction == nil, isCurrentAccount else { return false }
        guard let detail, !isStale, detail.version == command.expectedVersion, detail.actions.contains(command.action) else {
            isStale = true; message = Copy.changed; return false
        }
        activeAction = command.action; message = nil
        defer { activeAction = nil }
        do {
            let result = try await list.session.api.performReturn(scope: list.scope, detail: detail, command: command, draft: draft)
            guard isCurrentAccount else { return false }; receive(result); return true
        } catch { recordFailure(error); return false }
    }
    func receive(_ result: UFitReturnDetailDTO) {
        guard isCurrentAccount, result.id == id, list.scope.contains(orderID: result.orderId, brandID: result.brandId),
              detail == nil || result.version >= detail!.version else { return }
        detail = result; isStale = false; message = Copy.updated; list.receive(result.summary)
    }
    private func recordFailure(_ error: Error) {
        guard isCurrentAccount else { return }
        if (error as? UFitAPIError)?.losesReturnAccess == true { detail = nil; list.loseAccess(error) }
        if (error as? UFitAPIError)?.isReturnConflict == true { isStale = true }
        message = error.localizedDescription
    }
}
