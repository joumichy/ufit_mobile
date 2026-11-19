import Foundation
import Observation

@MainActor @Observable
final class UFitProfileAdministrationStore {
    private(set) var kind = UFitAdministeredProfileKind.creator
    private(set) var profiles = [UFitAdministeredProfileDTO]()
    private(set) var selected: UFitAdministeredProfileDTO?
    private(set) var history = [UFitProfileStatusChangeDTO]()
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var isDetailLoading = false
    private(set) var hasLoadedHistory = false
    private(set) var openingIDs = Set<String>()
    private(set) var listMessage: String?
    private(set) var detailMessage: String?
    private(set) var detailMessageIsError = false
    private(set) var nextCursor: String?
    private(set) var historyCursor: String?
    private(set) var decision: UFitProfileStatus?
    private(set) var reasonError: String?
    private(set) var isSaving = false
    private(set) var requiresReferenceReload = false
    var reason = String()
    @ObservationIgnored let collection: UFitUserAdministrationStore
    @ObservationIgnored let userID: String
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var navigation = UUID()
    init(collection: UFitUserAdministrationStore, userID: String, initialKind: UFitAdministeredProfileKind) {
        self.collection = collection; self.userID = userID; kind = initialKind
    }
    var isCurrentAccount: Bool { collection.isCurrentAccount }
    var hasDraft: Bool { !reason.isEmpty }
    var canSave: Bool { isCurrentAccount && !requiresReferenceReload && !isSaving && !isDetailLoading && decision != nil && selected?.allows(decision!) == true }
    func cancelLoading() { generation = UUID(); navigation = UUID(); isLoading = false; isDetailLoading = false; isSaving = false; openingIDs = [] }
    func chooseKind(_ kind: UFitAdministeredProfileKind) async {
        guard self.kind != kind else { return }
        cancelLoading(); self.kind = kind; profiles = []; nextCursor = nil; hasLoaded = false; listMessage = nil
        await load()
    }
    func load(refresh: Bool = true) async {
        guard isCurrentAccount, !isLoading, refresh || nextCursor != nil else { return }
        let request = generation, requestedKind = kind, cursor = refresh ? nil : nextCursor
        isLoading = true; listMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await collection.session.api.fetchAdministeredProfiles(userID: userID, kind: requestedKind, cursor: cursor)
            guard generation == request, isCurrentAccount, kind == requestedKind else { return }
            let merged = refresh ? page.items : profiles + page.items
            guard Set(merged.map(\.id)).count == merged.count, zip(merged, merged.dropFirst()).allSatisfy({ $0.id < $1.id }) else { throw UFitUserAdministrationFailure.page }
            profiles = merged; nextCursor = page.nextCursor; hasLoaded = true
        } catch {
            guard generation == request, isCurrentAccount else { return }
            recordFailure(error); listMessage = UFitProfileAdministrationError.message(error, resource: .list)
        }
    }
    func open(_ id: String) async {
        guard isCurrentAccount, !openingIDs.contains(id), profiles.contains(where: { $0.id == id }) else { return }
        let request = generation, destination = UUID(), requestedKind = kind; navigation = destination
        openingIDs.insert(id); listMessage = nil
        defer { if generation == request { openingIDs.remove(id) } }
        do {
            let profile = try await collection.session.api.fetchAdministeredProfile(userID: userID, kind: requestedKind, id: id)
            guard generation == request, navigation == destination, isCurrentAccount else { return }
            selected = profile; history = []; historyCursor = nil; hasLoadedHistory = false
            decision = nil; reason = String(); reasonError = nil; requiresReferenceReload = false; detailMessage = nil
            await loadDetail()
        } catch {
            guard generation == request, navigation == destination, isCurrentAccount else { return }
            recordFailure(error); listMessage = UFitProfileAdministrationError.message(error, resource: .detail)
        }
    }
    func closeDetail() {
        cancelLoading(); selected = nil; history = []; historyCursor = nil; decision = nil; reason = String(); reasonError = nil
        detailMessage = nil; requiresReferenceReload = false
    }
    func chooseDecision(_ status: UFitProfileStatus) {
        guard !isSaving, !isDetailLoading, !requiresReferenceReload, selected?.allows(status) == true else { return }
        decision = status; detailMessage = nil; reasonError = nil
    }
    func cancelDecision() { decision = nil; reason = String(); reasonError = nil; detailMessage = nil }
    func clearReasonError() { reasonError = nil }
    func loadDetail(refresh: Bool = true) async {
        guard isCurrentAccount, !isDetailLoading, !isSaving, let profile = selected, refresh || historyCursor != nil else { return }
        let request = generation, cursor = refresh ? nil : historyCursor
        isDetailLoading = true; detailMessage = nil; detailMessageIsError = false
        defer { if generation == request { isDetailLoading = false } }
        do {
            let current: UFitAdministeredProfileDTO
            let page: UFitUserAdministrationPageDTO<UFitProfileStatusChangeDTO>
            if refresh {
                async let fetched = collection.session.api.fetchAdministeredProfile(userID: userID, kind: profile.kind, id: profile.id)
                async let changes = collection.session.api.fetchProfileStatusHistory(userID: userID, kind: profile.kind, id: profile.id)
                (current, page) = try await (fetched, changes)
            } else {
                current = profile
                page = try await collection.session.api.fetchProfileStatusHistory(userID: userID, kind: profile.kind, id: profile.id, cursor: cursor)
            }
            guard generation == request, isCurrentAccount, selected?.id == profile.id else { return }
            let merged = refresh ? page.items : history + page.items
            guard merged.allSatisfy({ $0.version <= current.version }), Set(merged.map(\.id)).count == merged.count,
                  zip(merged, merged.dropFirst()).allSatisfy({ $0.version > $1.version }) else { throw UFitUserAdministrationFailure.page }
            selected = current; history = merged; historyCursor = page.nextCursor; hasLoadedHistory = true; requiresReferenceReload = false
            replace(current)
            if decision != nil { detailMessage = UFitProfileAdministrationCopy.referenceUpdated; detailMessageIsError = false }
        } catch {
            guard generation == request, isCurrentAccount else { return }
            recordFailure(error); requiresReferenceReload = true
            detailMessage = UFitProfileAdministrationError.message(error, resource: refresh ? .detail : .history); detailMessageIsError = true
        }
    }
    func save() async {
        guard canSave, let current = selected, let decision, let actorID = collection.session.user?.id else { return }
        let reason = UFitServerTextInput.trimmed(reason)
        guard UFitUserAdministrationContract.reason(reason) else { reasonError = UFitProfileAdministrationCopy.reasonRequired; return }
        let request = generation
        isSaving = true; reasonError = nil; detailMessage = nil
        defer { if generation == request { isSaving = false } }
        do {
            let result: UFitAdministeredProfileDTO
            do {
                result = try await collection.session.api.changeProfileStatus(userID: userID, current: current, status: decision, reason: reason)
            } catch {
                guard generation == request, isCurrentAccount, UFitUserAdministrationError.uncertain(error),
                      let recovered = try? await recover(original: current, status: decision, reason: reason, actorID: actorID) else { throw error }
                result = recovered
            }
            guard generation == request, isCurrentAccount else { return }
            selected = result; replace(result); self.decision = nil; self.reason = String(); requiresReferenceReload = false
            history = []; historyCursor = nil; hasLoadedHistory = false
            isSaving = false
            await loadDetail()
            if detailMessage == nil { detailMessage = UFitProfileAdministrationCopy.saved; detailMessageIsError = false }
        } catch {
            guard generation == request, isCurrentAccount else { return }
            recordFailure(error); requiresReferenceReload = true
            detailMessage = UFitUserAdministrationError.conflict(error) ? UFitProfileAdministrationCopy.conflict :
                UFitUserAdministrationError.uncertain(error) ? UFitProfileAdministrationCopy.uncertain : UFitProfileAdministrationError.message(error, resource: .detail)
            detailMessageIsError = true
        }
    }
    private func recover(original: UFitAdministeredProfileDTO, status: UFitProfileStatus, reason: String, actorID: String) async throws -> UFitAdministeredProfileDTO? {
        do {
            let current = try await collection.session.api.fetchAdministeredProfile(userID: userID, kind: original.kind, id: original.id)
            guard isCurrentAccount, current.version == original.version + UFitUserAdministrationContract.versionStep, current.status == status else { return nil }
            let page = try await collection.session.api.fetchProfileStatusHistory(userID: userID, kind: original.kind, id: original.id)
            guard isCurrentAccount, let change = page.items.first, change.version == current.version,
                  change.decidedByUserId == actorID, change.reason == reason, change.fromStatus == original.status, change.toStatus == status else { return nil }
            return current
        } catch {
            recordFailure(error)
            throw error
        }
    }
    private func replace(_ profile: UFitAdministeredProfileDTO) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id && $0.kind == profile.kind }) else { return }
        profiles[index] = profile
    }
    private func recordFailure(_ error: Error) {
        if UFitUserAdministrationError.revoked(error) {
            collection.recordReadFailure(error); profiles = []; selected = nil; history = []; nextCursor = nil; historyCursor = nil
            hasLoaded = false; hasLoadedHistory = false; decision = nil; reason = String()
        }
    }
}

private enum UFitProfileAdministrationError {
    enum Resource { case list, detail, history }
    private enum HTTP { static let missing = 404 }
    static func message(_ error: Error, resource: Resource) -> String {
        if case UFitAPIError.requestFailed(let status, _, _) = error, status == HTTP.missing { return UFitProfileAdministrationCopy.profileUnavailable }
        if UFitUserAdministrationError.uncertain(error) {
            switch resource {
            case .list: return UFitProfileAdministrationCopy.listFailure
            case .detail: return UFitProfileAdministrationCopy.detailFailure
            case .history: return UFitProfileAdministrationCopy.historyFailure
            }
        }
        return error.localizedDescription
    }
}
