import Foundation
import Observation

@MainActor @Observable
final class UFitReturnCreationStore: Identifiable {
    let id = UUID()
    let orderID: String
    let orderNumber: String
    var draft = UFitReturnCreationDraft() { didSet { if draft != oldValue && !isSaving { errors = [:]; if !isUnresolved { message = nil; quote = nil } } } }
    private(set) var options: UFitReturnOptionsDTO?
    private(set) var quote: UFitReturnQuoteDTO?
    private(set) var errors: [UFitReturnCreationField: String] = [:]
    private(set) var message: String?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var created: UFitReturnDetailDTO?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    @ObservationIgnored private let journal: UFitReturnCreationJournal
    @ObservationIgnored private var pending: UFitReturnCreationRequest?
    private(set) var journalUnavailable = false
    private enum Copy {
        static let invalid = String(localized: "Corrigez la sélection et le motif avant de continuer.")
        static let journalUnavailable = String(localized: "La demande enregistrée sur cet appareil ne peut pas être relue. Actualisez pour réessayer ; aucun nouvel envoi ne sera créé tant que sa référence n’est pas récupérée.")
        static let localRecovery = String(localized: "La demande est créée. Sa référence de reprise reste conservée sur cet appareil.")
    }
    init(orderID: String, orderNumber: String, session: UFitSessionStore) throws {
        guard UUID(uuidString: orderID) != nil, let userID = session.user?.id else { throw UFitAPIError.authenticationRequired }
        self.orderID = orderID; self.orderNumber = orderNumber; self.session = session; self.userID = userID
        journal = .init(userID: userID, orderID: orderID)
    }
    var isCurrentAccount: Bool { session.user?.id == userID }
    var isUnresolved: Bool { pending != nil || journalUnavailable }
    var hasChanges: Bool { draft != UFitReturnCreationDraft() || isUnresolved }
    var presentation: UFitReturnOptionsPresentation? { options?.presentation(orderNumber: orderNumber) }
    var preview: UFitReturnAmountsPresentation? { quote.map { $0.amounts.presentation(currency: $0.currency) } }
    func load() async {
        guard isCurrentAccount, !isLoading, !isSaving else { return }
        isLoading = true; message = nil; quote = nil
        defer { isLoading = false }
        do {
            pending = try journal.read(); journalUnavailable = false
            if let pending { draft = pending.draft; quote = nil }
        } catch { journalUnavailable = true; message = Copy.journalUnavailable; return }
        do {
            let result = try await session.api.fetchReturnOptions(orderID: orderID)
            guard isCurrentAccount else { return }; options = result
        } catch {
            guard isCurrentAccount else { return }
            if (error as? UFitAPIError)?.losesReturnAccess == true { options = nil; quote = nil }
            message = error.localizedDescription
        }
    }
    func verify() async {
        guard isCurrentAccount, !isLoading, !isSaving, !isUnresolved, let options, options.canRequest else { return }
        errors = UFitReturnInput.errors(draft, pieces: options.presentation(orderNumber: orderNumber).items)
        guard errors.isEmpty else { message = Copy.invalid; return }
        isLoading = true; quote = nil; message = nil
        defer { isLoading = false }
        do {
            let result = try await session.api.previewReturn(orderID: orderID, draft: draft, options: options)
            guard isCurrentAccount else { return }; quote = result
        } catch { guard isCurrentAccount else { return }; message = error.localizedDescription }
    }
    func edit() { guard !isSaving, !isUnresolved else { return }; quote = nil; message = nil }
    func submit() async -> UFitReturnDetailDTO? {
        guard isCurrentAccount, !isLoading, !isSaving, !journalUnavailable else { return nil }
        let request: UFitReturnCreationRequest
        do {
            if let pending { request = pending }
            else {
                guard let options, let quote else { throw UFitReturnContractError.draft }
                request = try .init(requestID: UUID().uuidString.lowercased(), draft: draft, quote: quote, options: options)
                try journal.record(request); pending = request
            }
        } catch { message = error.localizedDescription; return nil }
        isSaving = true; message = nil
        defer { isSaving = false }
        do {
            let result = try await session.api.createReturn(orderID: orderID, request: request)
            guard isCurrentAccount else { return nil }
            created = result; pending = nil; quote = nil; draft = UFitReturnCreationDraft()
            do { try journal.resolve() } catch { message = Copy.localRecovery }
            return result
        } catch {
            guard isCurrentAccount else { return nil }
            if let failure = (error as? UFitAPIError)?.returnFailure,
               [.quote, .quantity, .expired, .open].contains(failure) {
                // The server checks request identity before eligibility: these responses confirm no creation for this request.
                do { try journal.resolve(); pending = nil; quote = nil } catch { journalUnavailable = true }
            }
            message = error.localizedDescription; return nil
        }
    }
}
