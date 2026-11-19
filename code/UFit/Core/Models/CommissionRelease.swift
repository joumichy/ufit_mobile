import Foundation

struct UFitCommissionRelease: Decodable, Equatable {
    enum State: String, Decodable, CaseIterable {
        case estimated, awaitingDelivery = "awaiting_delivery", returnWindow = "return_window"
        case returnOpen = "return_open", cancellationOpen = "cancellation_open", payable, paid, cancelled
    }
    static func filterTitle(_ state: State) -> String {
        switch state {
        case .estimated: String(localized: "Estimées")
        case .awaitingDelivery: String(localized: "Livraison attendue")
        case .returnWindow: String(localized: "Délai de retour")
        case .returnOpen: String(localized: "Retour en cours")
        case .cancellationOpen: String(localized: "Annulation en cours")
        case .payable: String(localized: "Disponibles")
        case .paid: String(localized: "Payées")
        case .cancelled: String(localized: "Annulées")
        }
    }
    let state: State
    let availableAt: UFitTimestamp?
    private enum CodingKeys: String, CodingKey, CaseIterable { case state, availableAt }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
        let value = try decoder.container(keyedBy: CodingKeys.self)
        state = try value.decode(State.self, forKey: .state)
        availableAt = try value.decodeIfPresent(UFitTimestamp.self, forKey: .availableAt)
        switch state {
        case .returnWindow, .payable:
            guard availableAt != nil else { throw UFitWorkspaceFinanceFailure.document }
        case .estimated, .awaitingDelivery, .paid, .cancelled:
            guard availableAt == nil else { throw UFitWorkspaceFinanceFailure.document }
        case .returnOpen, .cancellationOpen: break
        }
    }
    var status: UFitCommissionState {
        switch state {
        case .estimated: .estimated
        case .paid: .paid
        case .cancelled: .cancelled
        case .payable: .validated
        case .awaitingDelivery, .returnWindow, .returnOpen, .cancellationOpen: .pending
        }
    }
    func summary() throws -> String {
        switch state {
        case .estimated: return Copy.estimated
        case .awaitingDelivery: return Copy.delivery
        case .returnWindow:
            guard let date = formattedDate else { throw UFitWorkspaceFinanceFailure.document }
            return String(localized: "Disponible après le \(date)")
        case .returnOpen: return Copy.returnOpen
        case .cancellationOpen: return Copy.cancellation
        case .payable: return Copy.payable
        case .paid: return Copy.paid
        case .cancelled: return Copy.cancelled
        }
    }
    var detailDate: String? {
        state == .returnWindow ? nil : formattedDate
    }
    private var formattedDate: String? {
        availableAt?.value.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(Copy.locale))
    }
    private enum Copy {
        static let locale = Locale(identifier: "fr_CH")
        static let estimated = String(localized: "Estimée")
        static let delivery = String(localized: "En attente de livraison")
        static let returnOpen = String(localized: "Versement suspendu pendant le retour")
        static let cancellation = String(localized: "Versement suspendu pendant l’annulation")
        static let payable = String(localized: "Disponible pour versement")
        static let paid = String(localized: "Payée")
        static let cancelled = String(localized: "Annulée")
    }
}
