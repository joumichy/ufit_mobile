import Foundation
import Observation

enum UFitStylePreferencesScope: Hashable { case restoring, guest, account(String) }

@MainActor @Observable
final class UFitStylePreferencesStore {
    var draft = Set<String>() {
        didSet {
            if !isBusy && pending == nil && comparison == nil { message = nil; messageKind = .information }
        }
    }
    private(set) var selectedIDs = Set<String>()
    private(set) var options: UFitOutfitDiscoveryOptions?
    private(set) var document: UFitStylePreferencesDocument?
    private(set) var pending: UFitStylePreferencesCommand?
    private(set) var comparison: Set<String>?
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var canRetry = false
    private(set) var requiresReload = false
    private(set) var message: String?
    private(set) var messageKind = UFitNoticeKind.information
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let storage = UFitStylePreferencesStorage()
    @ObservationIgnored private var activeScope: UFitStylePreferencesScope?
    @ObservationIgnored private var generation = UUID()
    private typealias Copy = UFitStylePreferencesCopy
    init(session: UFitSessionStore) { self.session = session }
    var scope: UFitStylePreferencesScope {
        if session.isRestoring { return .restoring }
        if session.isSignedIn {
            guard let id = session.user?.id else { return .restoring }
            return .account(id)
        }
        return .guest
    }
    var isCurrent: Bool { activeScope == scope && scope != .restoring }
    var styles: [UFitOutfitTag] { options?.tags.filter { $0.type == .style } ?? [] }
    var shortcuts: [UFitOutfitTag] { isCurrent && hasLoaded ? styles.filter { selectedIDs.contains($0.id) } : [] }
    var hasChanges: Bool { hasLoaded && draft != selectedIDs }
    var isBusy: Bool { isLoading || isSaving }
    var allowsEditing: Bool {
        isCurrent && hasLoaded && !isBusy && pending == nil && comparison == nil && !requiresReload
            && (document == nil || document!.version < UFitStylePreferencesHTTP.maximumVersion)
    }
    func summary(_ ids: Set<String>) -> String {
        ids.isEmpty ? Copy.empty : styles.filter { ids.contains($0.id) }.map(\.label).joined(separator: Copy.separator)
    }
    func activate() async {
        if activeScope != scope {
            generation = UUID(); activeScope = scope
            draft = []; selectedIDs = []; options = nil; document = nil; pending = nil; comparison = nil
            hasLoaded = false; isLoading = false; isSaving = false; canRetry = false; requiresReload = false; message = nil
        }
        if !hasLoaded { await load() }
    }
    func load() async {
        guard isCurrent, !isBusy else { return }
        let request = generation, keepDraft = hasChanges || comparison != nil
        isLoading = true; message = nil; messageKind = .information
        if pending != nil { canRetry = false }
        defer { if generation == request { isLoading = false } }
        do {
            if options == nil {
                let registry = try await session.api.fetchOutfitDiscoveryOptions()
                guard generation == request, isCurrent else { return }
                options = registry
            }
            switch scope {
            case .restoring: return
            case .guest:
                let ids = try storage.guest(); try validateAvailable(ids)
                selectedIDs = Set(ids); if !keepDraft { draft = selectedIDs }
                hasLoaded = true; requiresReload = false
            case .account(let userID):
                if let command = try storage.pending(userID: userID) {
                    pending = command; draft = Set(command.input.styleIds)
                    let status = try await session.api.fetchStylePreferenceChange(command)
                    guard generation == request, isCurrent else { return }
                    try receive(status, command: command)
                } else {
                    let current = try await session.api.fetchStylePreferences(userID: userID)
                    guard generation == request, isCurrent else { return }
                    try validateAvailable(current.styleIds)
                    let changed = document != nil && document?.version != current.version
                    document = current; selectedIDs = Set(current.styleIds); hasLoaded = true; requiresReload = false
                    if keepDraft && changed { comparison = selectedIDs; message = Copy.changed }
                    else if !keepDraft { draft = selectedIDs; comparison = nil }
                }
            }
        } catch {
            if generation == request, isCurrent {
                message = pending == nil ? Copy.loadFailed : Copy.uncertain; messageKind = .error
            }
        }
    }
    @discardableResult func save() async -> Bool {
        guard allowsEditing else { return false }
        if !hasChanges { return true }
        let ids = draft.sorted()
        do {
            try validateAvailable(ids)
            switch scope {
            case .restoring: return false
            case .guest:
                try storage.saveGuest(ids); selectedIDs = Set(ids); draft = selectedIDs
                message = Copy.saved; messageKind = .success; return true
            case .account(let userID):
                guard let document, document.userId == userID else { throw UFitStylePreferencesFailure.document }
                let command = UFitStylePreferencesCommand(userID: userID, input: .init(requestId: UUID().uuidString.lowercased(),
                    expectedVersion: document.version, styleIds: ids))
                try storage.record(command); pending = command; canRetry = false
            }
        } catch { message = error.localizedDescription; messageKind = .error; return false }
        return await sendPending()
    }
    @discardableResult func retry() async -> Bool {
        guard canRetry else { return false }
        return await sendPending()
    }
    func keepMine() { comparison = nil; message = nil }
    func keepCurrent() { draft = selectedIDs; comparison = nil; message = nil }
    func discardDraft() { if pending == nil { keepCurrent() } }

    private func sendPending() async -> Bool {
        guard isCurrent, !isBusy, let command = pending else { return false }
        let request = generation
        isSaving = true; canRetry = false; message = nil
        defer { if generation == request { isSaving = false } }
        do {
            _ = try await session.api.saveStylePreferences(command)
        } catch {
            guard generation == request, isCurrent else { return false }
            if UFitStylePreferencesFailure.definitivelyRejected(error) {
                do { try storage.resolve(userID: command.userID); pending = nil }
                catch { message = Copy.storageFailed; messageKind = .error; return false }
                isSaving = false
                if UFitStylePreferencesFailure.code(error) == UFitStylePreferencesHTTP.changed { requiresReload = true; await load() }
                else { message = Copy.unavailable; messageKind = .error }
                return false
            }
        }
        guard generation == request, isCurrent else { return false }
        do {
            let status = try await session.api.fetchStylePreferenceChange(command)
            guard generation == request, isCurrent else { return false }
            try receive(status, command: command)
        } catch { if generation == request, isCurrent { message = Copy.uncertain; messageKind = .error } }
        return generation == request && isCurrent && pending == nil && comparison == nil && !hasChanges
    }
    private func receive(_ status: UFitStylePreferenceChangeStatus, command: UFitStylePreferencesCommand) throws {
        try status.validate(command); try validateAvailable(status.preferences.styleIds)
        document = status.preferences; selectedIDs = Set(status.preferences.styleIds); hasLoaded = true; requiresReload = false
        if status.receipt == nil && status.preferences.version == command.input.expectedVersion {
            canRetry = true; message = Copy.notApplied; messageKind = .error; return
        }
        try storage.resolve(userID: command.userID); pending = nil; canRetry = false
        if status.receipt != nil && selectedIDs == Set(command.input.styleIds) {
            draft = selectedIDs; comparison = nil; message = Copy.saved; messageKind = .success
        } else { comparison = selectedIDs; message = Copy.changed; messageKind = .information }
    }
    private func validateAvailable(_ ids: [String]) throws {
        try validateStyleIDs(ids)
        guard Set(ids).isSubset(of: Set(styles.map(\.id))) else { throw UFitStylePreferencesFailure.document }
    }
}
