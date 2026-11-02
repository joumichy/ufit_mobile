import Foundation
import Observation

@MainActor @Observable
final class UFitBrandOrderStore {
    let id: String
    let list: UFitBrandOrdersStore
    private(set) var order: UFitBrandOrderDetailDTO?
    private(set) var isLoading = false
    private(set) var activeAction: UFitShipmentAction?
    private(set) var isStale = false
    private(set) var message: String?
    private enum Copy { static let updated = String(localized: "Commande actualisée.") }
    init(id: String, list: UFitBrandOrdersStore) throws {
        guard UUID(uuidString: id) != nil, list.isCurrentAccount else { throw UFitBrandOrderContractError.document }
        self.id = id; self.list = list
    }
    var isCurrentAccount: Bool { list.isCurrentAccount }
    var presentation: UFitBrandOrderPresentation? { order?.presentation(stale: isStale) }
    func load() async {
        guard !isLoading, activeAction == nil, isCurrentAccount else { return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            let result = try await list.session.api.fetchBrandOrder(brandID: list.brandID, orderID: id)
            guard isCurrentAccount else { return }
            order = result; isStale = false; list.receive(result.summary)
        } catch { recordFailure(error) }
    }
    func perform(_ command: UFitShipmentCommand) async {
        guard !isLoading, activeAction == nil, isCurrentAccount, !command.action.requiresForm else { return }
        guard let order, let shipment = order.shipment, !isStale, shipment.version == command.expectedVersion,
              order.actions.contains(command.action) else { recordFailure(UFitBrandOrderContractError.stale); return }
        activeAction = command.action; message = nil
        defer { activeAction = nil }
        do {
            let result = try await list.session.api.performShipment(brandID: list.brandID, orderID: id, shipmentID: shipment.id, command: command)
            receive(result)
        } catch { recordFailure(error) }
    }
    func receive(_ result: UFitShipmentResult) {
        guard isCurrentAccount, var current = order, let previous = current.shipment,
              result.shipment.brandId == list.brandID, result.shipment.orderId == id, result.shipment.id == previous.id,
              result.shipment.version >= previous.version else { return }
        current.receive(result); order = current; isStale = false; message = Copy.updated; list.receive(current.summary)
    }
    func recordFailure(_ error: Error) {
        guard isCurrentAccount else { return }
        if (error as? UFitAPIError)?.losesBrandOrderAccess == true { order = nil; list.loseAccess(error) }
        if (error as? UFitAPIError)?.isShipmentConflict == true || (error as? UFitBrandOrderContractError) == .stale { isStale = true }
        message = error.localizedDescription
    }
}
