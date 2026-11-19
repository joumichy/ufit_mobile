import Foundation
import Observation

@MainActor @Observable
final class UFitReturnActionStore: Identifiable {
    let id = UUID()
    let command: UFitReturnCommand
    let items: [UFitOrderPiece]
    let amount: String
    var draft: UFitReturnActionDraft { didSet { if draft != oldValue && !isSaving { errors = [:]; if !isStale { message = nil } } } }
    private(set) var errors: [UFitReturnActionField: String] = [:]
    private(set) var message: String?
    private(set) var isSaving = false
    private(set) var isStale = false
    private(set) var canRefresh = false
    private(set) var accessLost = false
    @ObservationIgnored private let original: UFitReturnActionDraft
    @ObservationIgnored let parent: UFitReturnDetailStore
    private enum Copy {
        static let invalid = String(localized: "Corrigez les champs indiqués avant l’enregistrement.")
        static let retained = String(localized: "Votre saisie est conservée."); static let space = " "
        static let changed = String(localized: "Le dossier a changé. Actualisez avant de continuer.")
    }
    init(parent: UFitReturnDetailStore, command: UFitReturnCommand) throws {
        guard parent.isCurrentAccount, !parent.isStale, !parent.isLoading, parent.activeAction == nil, command.action.requiresForm,
              let detail = parent.detail, detail.version == command.expectedVersion, detail.actions.contains(command.action) else { throw UFitReturnContractError.draft }
        self.parent = parent; self.command = command; items = detail.items.map { $0.presentation(currency: detail.currency) }; amount = UFitMoney.format(detail.amounts.totalAmount, currency: detail.currency)
        var initial = UFitReturnActionDraft()
        if command.action == .updateTracking, let tracking = detail.tracking {
            initial.carrier = tracking.carrier; initial.trackingNumber = tracking.trackingNumber; initial.trackingURL = tracking.trackingUrl ?? String()
        }
        draft = initial; original = initial
    }
    var hasChanges: Bool { !accessLost && draft != original }
    func save() async -> Bool {
        guard !isSaving, !isStale, parent.isCurrentAccount, !accessLost else { return false }
        errors = UFitReturnInput.errors(draft, action: command.action, pieces: items)
        guard errors.isEmpty else { message = Copy.invalid; return false }
        guard parent.detail?.version == command.expectedVersion, !parent.isStale else {
            isStale = true; canRefresh = true; message = Copy.changed + Copy.space + Copy.retained; return false
        }
        isSaving = true; message = nil
        defer { isSaving = false }
        if await parent.perform(command, draft: draft) { return true }
        guard parent.isCurrentAccount else { return false }
        canRefresh = true; isStale = parent.isStale
        if parent.detail == nil {
            accessLost = true; isStale = true; draft = UFitReturnActionDraft(); message = parent.message
        } else { message = (parent.message ?? Copy.changed) + Copy.space + Copy.retained }
        return false
    }
}
