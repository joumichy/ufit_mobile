import Foundation
import Observation

@MainActor @Observable
final class UFitExperienceStore {
    private(set) var selected = UFitExperienceSelection.customer
    private(set) var choices: [UFitExperienceChoice] = [UFitExperienceStore.customerChoice]
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var asksForChoice = false
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let workspaces: UFitWorkspacesStore
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var didAskForChoice = false
    init(session: UFitSessionStore, workspaces: UFitWorkspacesStore, preferences: UserDefaults = .standard) {
        self.session = session; self.workspaces = workspaces; self.preferences = preferences
    }
    var kind: UFitExperienceKind { selected.kind }
    var workspace: UFitWorkspaceReference? {
        switch selected {
        case .creator(let id): workspaces.spaces.first { $0.isCreator && $0.profileID == id }
        case .brand(let id): workspaces.spaces.first { !$0.isCreator && $0.profileID == id }
        case .customer, .administrator: nil
        }
    }
    var canChooseAnotherExperience: Bool { choices.count > Contract.singleChoice || message != nil }
    func canUse(_ space: UFitWorkspaceReference) -> Bool {
        guard let current = workspace, session.user != nil else { return false }
        return current.id == space.id && (current.status == .active || current.status == .paused)
    }
    func reset() {
        generation = UUID(); selected = .customer; choices = [Self.customerChoice]
        isLoading = false; message = nil; asksForChoice = false; didAskForChoice = false
    }
    func load() async {
        guard !isLoading else { return }
        guard let userID = session.user?.id else { reset(); return }
        let request = generation, previous = selected
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let identity = try await session.api.fetchCurrentUser()
            guard identity.id == userID else { await session.reloadProfile(); throw AccessFailure.identity }
            let roles = Set(identity.roles.map(\.rawValue))
            if Set(session.user?.roles.map(\.rawValue) ?? []) != roles || session.user?.status != identity.status {
                await session.reloadProfile()
                guard session.user?.id == userID, Set(session.user?.roles.map(\.rawValue) ?? []) == roles,
                    session.user?.status == identity.status else { throw AccessFailure.identity }
            }
            guard await workspaces.load() else { throw AccessFailure.workspaces }
            guard generation == request, session.user?.id == userID else { return }
            let available = availableChoices(identity)
            choices = available
            let preference = savedSelection(userID: userID)
            let eligible = available.filter { $0.canSelect && $0.selection.kind != .customer }
            if let preference, available.contains(where: { $0.selection == preference && $0.canSelect }) {
                selected = preference
            } else if preference != nil {
                preferences.removeObject(forKey: preferenceKey(userID))
                selected = .customer; message = Copy.changed; asksForChoice = true
            } else if previous.kind != .customer, available.contains(where: { $0.selection == previous && $0.canSelect }) {
                selected = previous
            } else if eligible.count == Contract.singleChoice {
                selected = eligible[Contract.first].selection
            } else {
                selected = .customer
                if eligible.count > Contract.singleChoice && !didAskForChoice { asksForChoice = true }
            }
        } catch {
            guard generation == request, session.user?.id == userID else { return }
            message = error.localizedDescription
        }
    }
    func choose(_ selection: UFitExperienceSelection) {
        guard selection == .customer || choices.contains(where: { $0.selection == selection && $0.canSelect }) else { return }
        selected = selection; asksForChoice = false; didAskForChoice = true
        if let userID = session.user?.id, let data = try? JSONEncoder().encode(selection) {
            preferences.set(data, forKey: preferenceKey(userID))
        }
    }
    func dismissChoiceRequest() { asksForChoice = false; didAskForChoice = true }
    private func availableChoices(_ identity: UFitCurrentUser) -> [UFitExperienceChoice] {
        var result = [Self.customerChoice]
        guard identity.status == Contract.activeUser else { return result }
        if identity.isCreator {
            result.append(contentsOf: workspaces.spaces.filter(\.isCreator).map { .init(selection: .creator($0.profileID), name: $0.name, status: $0.status) })
        }
        if identity.isBrandMember {
            result.append(contentsOf: workspaces.spaces.filter { !$0.isCreator }.map { .init(selection: .brand($0.profileID), name: $0.name, status: $0.status) })
        }
        if identity.canAdminister { result.append(.init(selection: .administrator, name: String(), status: nil)) }
        return result
    }
    private func savedSelection(userID: String) -> UFitExperienceSelection? {
        guard let data = preferences.data(forKey: preferenceKey(userID)) else { return nil }
        guard let value = try? JSONDecoder().decode(UFitExperienceSelection.self, from: data),
              value.profileID == nil || UUID(uuidString: value.profileID!) != nil else {
            preferences.removeObject(forKey: preferenceKey(userID)); return nil
        }
        return value
    }
    private func preferenceKey(_ userID: String) -> String { Contract.preferencePrefix + userID }
    private static var customerChoice: UFitExperienceChoice { .init(selection: .customer, name: String(), status: nil) }
    private enum Contract { static let activeUser = "active"; static let singleChoice = 1; static let first = 0; static let preferencePrefix = "ufit.experience." }
    private enum Copy { static let changed = String(localized: "Votre accès à cet espace a changé. Choisissez un autre espace.") }
    private enum AccessFailure: LocalizedError {
        case identity, workspaces
        var errorDescription: String? {
            switch self {
            case .identity: String(localized: "Votre compte a changé. Reconnectez-vous avant de continuer.")
            case .workspaces: String(localized: "Vos espaces sont indisponibles. Réessayez.")
            }
        }
    }
}
