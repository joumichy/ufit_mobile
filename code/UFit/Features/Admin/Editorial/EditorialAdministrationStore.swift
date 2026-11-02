import Foundation
import Observation

@MainActor @Observable
final class UFitEditorialEditor {
    var draft: UFitEditorialDraft {
        didSet {
            if draft.title != oldValue.title { errors[.title] = nil }
            if draft.subtitle != oldValue.subtitle { errors[.subtitle] = nil }
            if draft.description != oldValue.description { errors[.description] = nil }
            if draft.coverURL != oldValue.coverURL { errors[.cover] = nil }
            if draft.references != oldValue.references { errors[.references] = nil }
        }
    }
    var errors: [UFitEditorialField: String] = [:]
    var requiresReload = false
    var comparison: UFitManagedEditorialDetail?
    private(set) var original: UFitManagedEditorialDetail?
    private(set) var targetID: String?
    private(set) var expectedVersion: Int
    private(set) var baseline: UFitEditorialDraft
    init(original: UFitManagedEditorialDetail?) {
        self.original = original; targetID = original?.collection.id; expectedVersion = original?.collection.version ?? .zero
        let initial = original?.draft ?? UFitEditorialDraft()
        draft = initial; baseline = initial
    }
    init(command: UFitEditorialCommand, draft: UFitEditorialDraft) {
        self.draft = draft; baseline = UFitEditorialDraft(); targetID = command.collectionID
        expectedVersion = command.expectedVersion; requiresReload = command.collectionID != nil
    }
    var hasChanges: Bool { draft != baseline }
    func useMine() {
        guard let comparison, comparison.collection.status != .archived else { return }
        original = comparison; targetID = comparison.collection.id; expectedVersion = comparison.collection.version
        baseline = comparison.draft; self.comparison = nil; requiresReload = false
    }
    func useCurrent() {
        guard let comparison else { return }
        original = comparison; targetID = comparison.collection.id; expectedVersion = comparison.collection.version
        baseline = comparison.draft; draft = baseline; self.comparison = nil; requiresReload = false; errors = [:]
    }
    func move(_ id: String, direction: Int) {
        guard let index = draft.references.firstIndex(where: { $0.id == id }), draft.references.indices.contains(index + direction) else { return }
        draft.references.swapAt(index, index + direction)
    }
}

@MainActor @Observable
final class UFitEditorialAdministrationStore {
    let session: UFitSessionStore
    let actorID: String?
    var status: UFitEditorialStatus? = .draft
    var visibleRowID: String?
    private(set) var rows: [UFitManagedEditorial] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var isLoadingMore = false
    private(set) var nextCursor: String?
    private(set) var listError: String?
    private(set) var moreFailed = false
    private(set) var openingIDs = Set<String>()
    private(set) var rowErrors: [String: String] = [:]
    var detail: UFitManagedEditorialDetail?
    var editor: UFitEditorialEditor?
    private(set) var pending: UFitEditorialCommand?
    private(set) var canRetry = false
    private(set) var isWorking = false
    private(set) var isRefreshingDetail = false
    private(set) var message: String?
    private(set) var messageKind = UFitNoticeKind.information
    private(set) var accessDenied = false
    private(set) var storageReady = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var opening = UUID()
    @ObservationIgnored private var cursors = Set<String>()
    @ObservationIgnored private let storage = UFitEditorialCommandStorage()
    private typealias Copy = UFitEditorialAdminCopy
    init(session: UFitSessionStore) { self.session = session; actorID = session.user?.id }
    var isCurrentAccount: Bool { actorID != nil && actorID == session.user?.id && session.user?.canAdminister == true && !accessDenied }
    var allowsMutation: Bool { isCurrentAccount && storageReady && !isWorking && !isRefreshingDetail && pending == nil }
    func cancelLoading() { generation = UUID(); isLoading = false; isLoadingMore = false; openingIDs = []; isRefreshingDetail = false }
    func activate() async {
        guard isCurrentAccount, let actorID else { return }
        do {
            pending = try storage.read(actorID: actorID); storageReady = true
            if let pending, let draft = pending.draft, editor == nil { editor = UFitEditorialEditor(command: pending, draft: draft) }
        }
        catch { storageReady = false; report(Copy.storageFailed); return }
        if pending != nil { await recover() }
        if !hasLoaded { await load() }
    }
    func filter(_ value: UFitEditorialStatus?) async {
        guard !isWorking else { return }
        cancelLoading(); status = value; rows = []; visibleRowID = nil; nextCursor = nil; hasLoaded = false; listError = nil; cursors = []
        await load()
    }
    func load(more: Bool = false) async {
        guard isCurrentAccount, !isLoading, !isLoadingMore, !more || nextCursor != nil else { return }
        let request = generation, cursor = more ? nextCursor : nil, filter = status
        if more { isLoadingMore = true } else { isLoading = true }
        listError = nil; moreFailed = false
        defer { if generation == request { isLoading = false; isLoadingMore = false } }
        do {
            let page = try await session.api.fetchManagedEditorial(status: filter, cursor: cursor)
            guard generation == request, isCurrentAccount else { return }
            if more {
                guard let cursor, !cursors.contains(cursor), Set(rows.map(\.id)).isDisjoint(with: page.items.map(\.id)) else { throw UFitEditorialFailure.contract }
                rows.append(contentsOf: page.items); cursors.insert(cursor)
            } else {
                rows = page.items; cursors = []
                if let visibleRowID, !rows.contains(where: { $0.id == visibleRowID }) { self.visibleRowID = nil }
            }
            nextCursor = page.nextCursor; hasLoaded = true
        } catch { if generation == request, isCurrentAccount { revokeIfNeeded(error); listError = more ? UFitEditorialCopy.moreFailed : Copy.loadFailed; moreFailed = more } }
    }
    func open(_ id: String) async {
        guard isCurrentAccount, !openingIDs.contains(id), rows.contains(where: { $0.id == id }) else { return }
        let request = generation, intent = UUID(); opening = intent; visibleRowID = id; openingIDs.insert(id); rowErrors[id] = nil
        defer { if generation == request { openingIDs.remove(id) } }
        do {
            let value = try await session.api.fetchManagedEditorial(id: id)
            guard generation == request, opening == intent, isCurrentAccount, editor == nil else { return }
            detail = value; message = nil
        } catch { if generation == request, isCurrentAccount { revokeIfNeeded(error); rowErrors[id] = Copy.openFailed } }
    }
    func create() { guard allowsMutation else { return }; editor = UFitEditorialEditor(original: nil); message = nil }
    func edit() {
        guard allowsMutation, let detail, detail.collection.status != .archived else { return }
        editor = UFitEditorialEditor(original: detail); message = nil
    }
    func back() -> Bool {
        guard !isWorking else { return true }
        if editor != nil { editor = nil; message = nil; return true }
        if detail != nil { detail = nil; message = nil; return true }
        return false
    }
    func refreshDetail() async {
        guard isCurrentAccount, !isWorking, !isRefreshingDetail, let id = editor?.targetID ?? detail?.collection.id else { return }
        let request = generation; isRefreshingDetail = true; message = nil
        defer { if generation == request { isRefreshingDetail = false } }
        do {
            let current = try await session.api.fetchManagedEditorial(id: id)
            guard generation == request, isCurrentAccount else { return }
            detail = current
            if let index = rows.firstIndex(where: { $0.id == id }) {
                if status == nil || status == current.collection.status { rows[index] = current.collection }
                else { rows.remove(at: index) }
            }
            if let editor { editor.comparison = current; editor.requiresReload = true; report(Copy.compare, kind: .information) }
        } catch { if generation == request, isCurrentAccount { revokeIfNeeded(error); report(Copy.openFailed) } }
    }
    func save() async {
        guard allowsMutation, let editor, !editor.requiresReload, editor.comparison == nil, editor.original?.collection.status != .archived else { return }
        editor.errors = editor.draft.errors
        guard editor.errors.isEmpty, editor.targetID == nil || editor.hasChanges else { return }
        await submit(kind: editor.targetID == nil ? .create : .edit, id: editor.targetID,
            version: editor.expectedVersion, draft: editor.draft)
    }
    func useComparison(keepDraft: Bool) {
        guard allowsMutation, let editor, let current = editor.comparison else { return }
        if keepDraft { guard current.collection.status != .archived else { return }; editor.useMine() }
        else if current.collection.status == .archived { detail = current; self.editor = nil }
        else { editor.useCurrent() }
        message = nil
    }
    func transition(_ kind: UFitEditorialCommandKind) async {
        guard allowsMutation, editor == nil, let detail else { return }
        let status = detail.collection.status
        guard (kind == .publish && status == .draft && !detail.items.isEmpty && detail.items.allSatisfy(\.available)) ||
              (kind == .archive && status != .archived) || (kind == .restore && status == .archived) else { return }
        await submit(kind: kind, id: detail.collection.id, version: detail.collection.version, draft: nil)
    }
    private func submit(kind: UFitEditorialCommandKind, id: String?, version: Int, draft: UFitEditorialDraft?) async {
        guard let actorID else { return }
        let command = UFitEditorialCommand(actorID: actorID, requestID: UUID().uuidString.lowercased(), collectionID: id,
            kind: kind, expectedVersion: version, draft: draft)
        do { try storage.record(command); pending = command; canRetry = false }
        catch { storageReady = false; report(Copy.storageFailed); return }
        await sendPending()
    }
    func retry() async { guard canRetry else { return }; await sendPending() }
    private func sendPending() async {
        guard isCurrentAccount, !isWorking, let command = pending else { return }
        let request = generation; isWorking = true; canRetry = false; message = nil
        defer { isWorking = false }
        do { _ = try await session.api.sendEditorialCommand(command) }
        catch {
            guard generation == request, isCurrentAccount else { return }
            if Self.definitive(error) {
                do { try storage.resolve(actorID: command.actorID); pending = nil }
                catch { report(Copy.storageFailed); return }
                if editor == nil, let draft = command.draft { editor = UFitEditorialEditor(command: command, draft: draft) }
                revokeIfNeeded(error)
                if UFitEditorialFailure.status(error) == UFitEditorialHTTP.changed {
                    editor?.requiresReload = true; report(Copy.changed)
                } else { report(Copy.rejected) }
                return
            }
        }
        guard generation == request, isCurrentAccount else { return }
        await readReceipt(command, generation: request)
    }
    func recover() async {
        guard isCurrentAccount, !isWorking, let pending else { return }
        let request = generation; isWorking = true; canRetry = false; message = nil
        defer { isWorking = false }
        await readReceipt(pending, generation: request)
    }
    private func readReceipt(_ command: UFitEditorialCommand, generation request: UUID) async {
        do {
            let status = try await session.api.fetchEditorialChange(command)
            guard generation == request, isCurrentAccount else { return }
            guard let receipt = status.receipt, let current = status.current else { canRetry = true; report(Copy.notApplied); return }
            try storage.resolve(actorID: command.actorID); pending = nil; canRetry = false
            detail = current; editor = nil; hasLoaded = false
            report(current.collection.version == receipt.version ? Copy.saved : Copy.savedThenChanged, kind: .success)
        } catch { if generation == request, isCurrentAccount { revokeIfNeeded(error); report(Copy.uncertain) } }
    }
    private func revokeIfNeeded(_ error: Error) {
        if case .authenticationRequired = error as? UFitAPIError { accessDenied = true }
        if let status = UFitEditorialFailure.status(error), [UFitEditorialAdminHTTP.unauthorized, UFitEditorialAdminHTTP.forbidden].contains(status) { accessDenied = true }
        if accessDenied { rows = []; detail = nil; editor = nil; nextCursor = nil }
    }
    private func report(_ text: String, kind: UFitNoticeKind = .error) { message = text; messageKind = kind }
    private static func definitive(_ error: Error) -> Bool {
        if case .authenticationRequired = error as? UFitAPIError { return true }
        guard let status = UFitEditorialFailure.status(error) else { return false }
        return [UFitEditorialAdminHTTP.badRequest, UFitEditorialAdminHTTP.unauthorized, UFitEditorialAdminHTTP.forbidden, UFitEditorialHTTP.missing, UFitEditorialHTTP.changed].contains(status)
    }
}
