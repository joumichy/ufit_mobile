import Foundation
import Observation

@MainActor @Observable
final class UFitApplicationReviewStore {
    let kind: UFitApplicationKind
    let id: String
    private(set) var application: UFitApplicationDocument?
    private(set) var isLoading = false
    private(set) var isDeciding = false
    private(set) var message: String?
    var notes = String()
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let queue: UFitApplicationQueueStore
    @ObservationIgnored private var requiresRefresh = false
    var allowsDecision: Bool { !requiresRefresh }
    private enum Contract { static let minNotes = 2; static let maxNotes = 2000 }
    private enum Copy {
        static let notes = String(localized: "Saisissez un message de 2 à 2 000 caractères, ou laissez-le vide pour une acceptation.")
        static let success = String(localized: "Décision enregistrée. Le candidat peut consulter le résultat.")
    }
    init(kind: UFitApplicationKind, id: String, client: UFitAPIClient, session: UFitSessionStore, queue: UFitApplicationQueueStore) {
        self.kind = kind; self.id = id; self.client = client; self.session = session; self.queue = queue
    }
    func load() async {
        guard !isLoading, !isDeciding, session.user?.canAdminister == true, let userID = session.user?.id else { return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            let document = try await client.fetchAdminApplication(kind: kind, id: id)
            guard session.user?.id == userID else { return }
            application = document; requiresRefresh = false
        } catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
    func decide(_ decision: UFitApplicationDecision) async {
        guard !isLoading, !isDeciding, !requiresRefresh, let application, application.metadata.status.canReview,
              session.user?.canAdminister == true, let userID = session.user?.id else { return }
        let text = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let validNotes = text.isEmpty || (Contract.minNotes...Contract.maxNotes).contains(text.count)
        guard validNotes && (decision == .accept || !text.isEmpty) else { message = Copy.notes; return }
        isDeciding = true; message = nil
        defer { isDeciding = false }
        do {
            let result = try await client.reviewApplication(application, decision: decision, notes: text.isEmpty ? nil : text)
            guard session.user?.id == userID else { return }
            self.application = result; notes = String(); message = Copy.success
            await queue.load()
        } catch {
            guard session.user?.id == userID else { return }
            message = error.localizedDescription
            if let failure = error as? UFitAPIError, failure.isApplicationVersionConflict { requiresRefresh = true }
        }
    }
}
