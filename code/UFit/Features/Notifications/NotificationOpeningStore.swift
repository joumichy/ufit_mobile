import Foundation
import Observation

@MainActor @Observable
final class UFitNotificationOpeningStore {
    private(set) var phase = UFitNotificationOpeningPhase.waiting
    private(set) var hasPending = false
    private(set) var destination: UFitNotificationDestination?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private var pending: Pending?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var isLoading = false
    private struct Pending: Codable { let id: String; var userID: String? }
    private enum Copy {
        static let profile = String(localized: "Votre compte n’a pas pu être chargé. Réessayez pour ouvrir ce message.")
        static let unavailable = String(localized: "Le service est momentanément indisponible. Réessayez pour ouvrir ce message.")
    }
    private enum Contract { static let key = "ufit.notification.pending"; static let denied: Set<Int> = [403, 404, 410]; static let unavailableStatus = 500 }
    init(session: UFitSessionStore, preferences: UserDefaults = .standard) {
        self.session = session; self.preferences = preferences
        if let data = preferences.data(forKey: Contract.key), let value = try? JSONDecoder().decode(Pending.self, from: data),
           UUID(uuidString: value.id)?.uuidString.lowercased() == value.id {
            pending = value; hasPending = true
        } else { preferences.removeObject(forKey: Contract.key) }
    }
    @discardableResult func accept(_ url: URL) -> Bool {
        guard UFitNotificationLink.recognizes(url) else { return false }
        generation = UUID(); destination = nil; isLoading = false; hasPending = true
        if let id = UFitNotificationLink.identifier(url) { pending = .init(id: id, userID: session.user?.id); phase = .waiting; persist() }
        else { pending = nil; phase = .unavailable; preferences.removeObject(forKey: Contract.key) }
        return true
    }
    func accountChanged(previous: String?, current: String?) {
        if let previous, previous != current { cancel() }
    }
    func cancel() {
        generation = UUID(); pending = nil; destination = nil; hasPending = false; isLoading = false; phase = .waiting
        preferences.removeObject(forKey: Contract.key)
    }
    func fail(_ error: Error) { destination = nil; phase = .failed(error.localizedDescription) }
    func resolve() async {
        guard hasPending, let pending, !isLoading else { return }
        guard !session.isRestoring else { phase = .waiting; return }
        guard let userID = session.user?.id else { phase = session.isSignedIn ? .failed(Copy.profile) : .signIn; return }
        if let owner = pending.userID, owner != userID {
            self.pending = nil; preferences.removeObject(forKey: Contract.key); phase = .unavailable; return
        }
        self.pending?.userID = userID; persist()
        let request = generation
        isLoading = true; phase = .loading; destination = nil
        defer { if generation == request { isLoading = false } }
        do {
            let detail = try await session.api.fetchNotification(id: pending.id)
            guard request == generation, session.user?.id == userID else { return }
            destination = detail.destination; phase = .ready
        } catch {
            guard request == generation, session.user?.id == userID else { return }
            if case .requestFailed(let status, _, _) = error as? UFitAPIError {
                if Contract.denied.contains(status) { phase = .unavailable }
                else { phase = .failed(status >= Contract.unavailableStatus ? Copy.unavailable : error.localizedDescription) }
            } else { phase = .failed(error.localizedDescription) }
        }
    }
    private func persist() {
        guard let pending, let data = try? JSONEncoder().encode(pending) else { return }
        preferences.set(data, forKey: Contract.key)
    }
}
