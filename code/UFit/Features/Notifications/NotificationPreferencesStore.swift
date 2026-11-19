import Foundation
import Observation

@MainActor @Observable
final class UFitNotificationPreferencesStore {
    var draft = UFitNotificationChoices(emailEnabled: false, pushEnabled: false) {
        didSet { if !isLoading && !isSaving && !requiresReload { message = nil; messageKind = .information } }
    }
    private(set) var document: UFitNotificationPreferencesDTO?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var requiresReload = false
    private(set) var comparison: UFitNotificationChoices?
    private(set) var message: String?
    private(set) var messageKind = UFitNoticeKind.information
    let userID: String
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var generation = UUID()
    private typealias Copy = UFitNotificationPreferencesCopy
    init(userID: String, session: UFitSessionStore) { self.userID = userID; self.session = session }
    var isCurrentAccount: Bool { session.isSignedIn && session.user?.id == userID }
    var hasChanges: Bool { document.map { draft != $0.choices } ?? false }
    func cancelLoading() { generation = UUID(); isLoading = false; isSaving = false }
    func load() async {
        guard isCurrentAccount, !isLoading, !isSaving else { return }
        let request = generation, keepDraft = hasChanges || requiresReload
        isLoading = true; message = nil; messageKind = .information
        defer { if generation == request { isLoading = false } }
        do {
            let current = try await session.api.fetchNotificationPreferences(userID: userID)
            guard generation == request, isCurrentAccount else { return }
            document = current; requiresReload = false
            if keepDraft { comparison = current.choices; message = Copy.refreshed }
            else { draft = current.choices; comparison = nil }
        } catch {
            guard generation == request, isCurrentAccount else { return }
            message = Copy.loadFailed; messageKind = .error
        }
    }
    func save() async {
        guard isCurrentAccount, !isLoading, !isSaving, !requiresReload, hasChanges, let previous = document, previous.allowsEditing else { return }
        let request = generation, submitted = draft
        isSaving = true; message = nil; messageKind = .information
        defer { if generation == request { isSaving = false } }
        do {
            let result = try await session.api.saveNotificationPreferences(previous, choices: submitted)
            guard generation == request, isCurrentAccount else { return }
            accept(result)
        } catch {
            guard generation == request, isCurrentAccount else { return }
            if UFitNotificationPreferencesFailure.conflict(error) {
                requiresReload = true; message = Copy.changed; messageKind = .error; return
            }
            if UFitNotificationPreferencesFailure.mayHaveSaved(error) {
                if let current = try? await session.api.fetchNotificationPreferences(userID: userID) {
                    guard generation == request, isCurrentAccount else { return }
                    if current.confirms(submitted, after: previous) { accept(current); return }
                }
                guard generation == request, isCurrentAccount else { return }
                requiresReload = true; message = Copy.uncertain
            } else { message = error.localizedDescription }
            messageKind = .error
        }
    }
    private func accept(_ current: UFitNotificationPreferencesDTO) {
        document = current; draft = current.choices; comparison = nil; requiresReload = false
        message = Copy.saved; messageKind = .success
    }
}
