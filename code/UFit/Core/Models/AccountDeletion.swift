import Foundation
import Security

enum UFitAccountDeletionHTTP {
    static let root = "account-deletions", separator = "/", get = "GET", put = "PUT"
    static let proofHeader = "x-ufit-deletion-key", notFound = 404
    static let secretBytes = 32, proofLength = 64, hexByte = "%02x"
    static let alphabet = CharacterSet(charactersIn: "0123456789abcdef")
    static let polling: Duration = .seconds(3)
    static func identifier(_ value: String) -> Bool { UUID(uuidString: value)?.uuidString.lowercased() == value }
}
enum UFitAccountDeletionPhase: String, Codable, Hashable { case purging = "purging_media", revoking = "revoking_auth", completed }
struct UFitAccountDeletionReceipt: Codable {
    let requestId: String
    let phase: UFitAccountDeletionPhase
    let requestedAt: String
    let completedAt: String?
    private enum CodingKeys: String, CodingKey { case requestId, phase, requestedAt, completedAt }
    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try fields.decode(String.self, forKey: .requestId)
        phase = try fields.decode(UFitAccountDeletionPhase.self, forKey: .phase)
        requestedAt = try fields.decode(String.self, forKey: .requestedAt)
        completedAt = try fields.decode(String?.self, forKey: .completedAt)
        try validate(requestID: requestId)
    }
    func encode(to encoder: Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(requestId, forKey: .requestId); try fields.encode(phase, forKey: .phase)
        try fields.encode(requestedAt, forKey: .requestedAt); try fields.encode(completedAt, forKey: .completedAt)
    }
    func validate(requestID: String) throws {
        guard requestId == requestID, UFitAccountDeletionHTTP.identifier(requestId),
              let requested = UFitTimestamp(isoString: requestedAt),
              (phase == .completed) == (completedAt != nil) else { throw UFitAccountDeletionFailure.receipt }
        if let completedAt {
            guard let completed = UFitTimestamp(isoString: completedAt), completed.value >= requested.value else { throw UFitAccountDeletionFailure.receipt }
        }
    }
}
struct UFitAccountDeletionRequest: Codable {
    let id: String, proof: String, userID: String, authSubject: String
    var receipt: UFitAccountDeletionReceipt?
    static func create(userID: String, authSubject: UUID) throws -> Self {
        var bytes = [UInt8](repeating: .zero, count: UFitAccountDeletionHTTP.secretBytes)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw UFitAccountDeletionFailure.storage }
        let request = Self(id: UUID().uuidString.lowercased(), proof: bytes.map { String(format: UFitAccountDeletionHTTP.hexByte, $0) }.joined(),
            userID: userID, authSubject: authSubject.uuidString.lowercased())
        try request.validate(); return request
    }
    func validate() throws {
        guard [id, userID, authSubject].allSatisfy(UFitAccountDeletionHTTP.identifier),
              proof.count == UFitAccountDeletionHTTP.proofLength,
              proof.unicodeScalars.allSatisfy(UFitAccountDeletionHTTP.alphabet.contains) else { throw UFitAccountDeletionFailure.storage }
        try receipt?.validate(requestID: id)
    }
}
enum UFitAccountDeletionFailure: LocalizedError {
    case storage, receipt
    var errorDescription: String? {
        switch self {
        case .storage: String(localized: "Le suivi de la demande ne peut pas être conservé sur cet iPhone. Réessayez avant de continuer.")
        case .receipt: String(localized: "Le résultat de la suppression n’a pas pu être vérifié. Actualisez son suivi.")
        }
    }
}
enum UFitAccountDeletionCopy {
    static let title = String(localized: "Supprimer mon compte")
    static let reviewTitle = String(localized: "Quitter Ufit")
    static let introduction = String(localized: "Votre compte sera fermé et vos données personnelles anonymisées. Cette action est définitive.")
    static let personal = String(localized: "Votre profil, vos favoris et vos publications seront retirés.")
    static let orders = String(localized: "Les informations nécessaires aux commandes, retours et obligations comptables seront conservées.")
    static let brands = String(localized: "Une marque partagée reste accessible à ses autres propriétaires. Sans autre propriétaire actif, ses nouvelles ventes sont suspendues.")
    static let confirm = String(localized: "Supprimer définitivement")
    static let cancel = String(localized: "Conserver mon compte")
    static let sending = String(localized: "Envoi de la demande…")
    static let sendingTitle = String(localized: "Envoi de la demande")
    static let sendingDetail = String(localized: "La demande est en cours d’envoi. La suppression n’est pas encore confirmée.")
    static let checking = String(localized: "Vérification du suivi…")
    static let pending = String(localized: "Suppression en cours")
    static let pendingDetail = String(localized: "Votre compte est fermé. Ufit termine la suppression des médias personnels et des accès. Vous pouvez revenir ici pour suivre son achèvement.")
    static let completed = String(localized: "Votre compte est supprimé")
    static let completedDetail = String(localized: "Vos accès ont été supprimés. Les données nécessaires aux commandes restent conservées.")
    static let uncertain = String(localized: "Demande à vérifier")
    static let uncertainDetail = String(localized: "La réponse n’a pas été confirmée. Votre suivi est conservé sur cet iPhone. Actualisez avant de renouveler la demande.")
    static let unavailable = String(localized: "Aucune suppression confirmée. Vous pouvez réessayer avec le même compte.")
    static let retry = String(localized: "Réessayer la demande")
    static let refresh = String(localized: "Actualiser le suivi")
    static let follow = String(localized: "Suivre la suppression du compte")
    static let browse = String(localized: "Continuer à découvrir")
    static let done = String(localized: "Terminer")
    static let close = String(localized: "Fermer")
    static let administrator = String(localized: "Un autre super-administrateur actif doit être désigné avant de supprimer ce compte.")
    static let authority = String(localized: "La suppression est momentanément indisponible. Votre compte reste ouvert. Réessayez plus tard.")
    static let signIn = String(localized: "Reconnectez-vous au compte concerné pour renouveler cette demande.")
    static let icon = "person.crop.circle.badge.minus", successIcon = "checkmark.circle", pendingIcon = "clock"
    static let administratorCode = "account_deletion_last_administrator", authorityCode = "account_deletion_authority_required"
}
