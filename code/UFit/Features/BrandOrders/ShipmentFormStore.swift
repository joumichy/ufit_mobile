import Foundation
import Observation

@MainActor @Observable
final class UFitShipmentFormStore: Identifiable {
    let id = UUID()
    let command: UFitShipmentCommand
    var draft: UFitShipmentFormDraft { didSet { if draft != oldValue && !isSaving { errors = [:]; if !isStale { message = nil } } } }
    private(set) var errors: [UFitShipmentFormField: String] = [:]
    private(set) var message: String?
    private(set) var isSaving = false
    private(set) var isStale = false
    private(set) var canRefresh = false
    private(set) var accessLost = false
    @ObservationIgnored private let original: UFitShipmentFormDraft
    @ObservationIgnored private let parent: UFitBrandOrderStore
    @ObservationIgnored private let shipmentID: String
    private enum Copy {
        static let invalid = String(localized: "Corrigez les champs indiqués avant l’enregistrement.")
        static let retained = String(localized: "Votre saisie est conservée.")
        static let space = " "
    }
    init(parent: UFitBrandOrderStore, command: UFitShipmentCommand) throws {
        guard parent.isCurrentAccount, !parent.isStale, !parent.isLoading, parent.activeAction == nil,
              command.action.requiresForm, let order = parent.order, let shipment = order.shipment,
              shipment.version == command.expectedVersion, order.actions.contains(command.action) else { throw UFitBrandOrderContractError.stale }
        self.parent = parent; self.command = command; shipmentID = shipment.id
        var initial = UFitShipmentFormDraft()
        if command.action == .updateTracking {
            initial.carrier = shipment.carrier ?? String(); initial.trackingNumber = shipment.trackingNumber ?? String(); initial.trackingURL = shipment.trackingUrl ?? String()
        }
        draft = initial; original = initial
    }
    var hasChanges: Bool { !accessLost && draft != original }
    func save() async -> Bool {
        guard !isSaving, !isStale, parent.isCurrentAccount, !accessLost else { return false }
        errors = UFitShipmentInput.errors(draft, action: command.action)
        guard errors.isEmpty else { message = Copy.invalid; return false }
        guard parent.order?.shipment?.version == command.expectedVersion, !parent.isStale else {
            isStale = true; canRefresh = true; message = UFitBrandOrderContractError.stale.localizedDescription + Copy.space + Copy.retained; return false
        }
        isSaving = true; message = nil
        defer { isSaving = false }
        do {
            let result = try await parent.list.session.api.performShipment(brandID: parent.list.brandID, orderID: parent.id,
                shipmentID: shipmentID, command: command, draft: draft)
            guard parent.isCurrentAccount else { return false }
            parent.receive(result); return true
        } catch {
            guard parent.isCurrentAccount else { return false }
            parent.recordFailure(error); canRefresh = true
            if (error as? UFitAPIError)?.losesBrandOrderAccess == true {
                accessLost = true; isStale = true; draft = UFitShipmentFormDraft(); message = error.localizedDescription
            } else {
                isStale = (error as? UFitAPIError)?.isShipmentConflict == true || (error as? UFitBrandOrderContractError) == .stale
                message = error.localizedDescription + Copy.space + Copy.retained
            }
            return false
        }
    }
}
