import Foundation

enum UFitRefundProofCopy {
    static let title = String(localized: "Justificatif du remboursement")
    static let upload = String(localized: "Joindre un justificatif")
    static let resume = String(localized: "Vérifier l’envoi du justificatif")
    static let choose = String(localized: "Choisir un document")
    static let replace = String(localized: "Changer de document")
    static let reference = String(localized: "Référence du virement")
    static let date = String(localized: "Date du virement (AAAA-MM-JJ)")
    static let dateLabel = String(localized: "Date du virement")
    static let submit = String(localized: "Soumettre le justificatif")
    static let sharing = String(localized: "Ce justificatif sera accessible au client et à l’administration Ufit. Sa soumission ne confirme pas encore le remboursement.")
    static let accepted = String(localized: "Justificatif transmis")
    static let review = String(localized: "Justificatif à vérifier")
    static let view = String(localized: "Voir le justificatif")
    static let downloadFailure = String(localized: "Le justificatif ne peut pas être ouvert. Réessayez.")
    static let fileRule = String(localized: "Choisissez un PDF ou une image JPEG de 8 Mo maximum.")
    static let dateRule = String(localized: "Indiquez une date valide au format AAAA-MM-JJ, au plus tard aujourd’hui.")
    static let missingFile = String(localized: "Choisissez le justificatif à joindre.")
    static let uncertain = String(localized: "La réponse n’a pas été confirmée. Vérifiez l’enregistrement avant de modifier la demande.")
    static let notSubmitted = String(localized: "Le justificatif n’est pas encore soumis. Vous pouvez renvoyer la même demande et le même fichier.")
    static let localFailure = String(localized: "La demande locale ne peut pas être relue. Revenez au dossier pour vérifier le justificatif avant une nouvelle saisie.")
    static let cancelled = String(localized: "Document non sélectionné.")
}
enum UFitRefundProofFailure: LocalizedError {
    case file, local
    var errorDescription: String? {switch self {case .file: UFitRefundProofCopy.fileRule; case .local: UFitRefundProofCopy.localFailure}}
}
struct UFitRefundProofSelection: Codable, Equatable {
    let name: String
    let contentType: String
    let bytes: Data
    var sha256: String {UFitRefundProofContract.hash(bytes)}
    init(url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer {if access {url.stopAccessingSecurityScopedResource()}}
        let attributes = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard attributes.isRegularFile == true, let size = attributes.fileSize, size <= UFitRefundProofContract.maximumBytes else {throw UFitRefundProofFailure.file}
        name = url.lastPathComponent; bytes = try Data(contentsOf: url)
        if bytes.starts(with: Signature.pdf) {contentType = UFitRefundProofContract.pdf}
        else if bytes.starts(with: Signature.jpeg) {contentType = UFitRefundProofContract.jpeg}
        else {throw UFitRefundProofFailure.file}
        try validate()
    }
    func validate() throws {
        guard (UFitRefundProofContract.minimumBytes...UFitRefundProofContract.maximumBytes).contains(bytes.count), !name.isEmpty,
              (contentType == UFitRefundProofContract.pdf && bytes.starts(with: Signature.pdf)) ||
              (contentType == UFitRefundProofContract.jpeg && bytes.starts(with: Signature.jpeg) && bytes.suffix(Signature.jpegEnd.count) == Signature.jpegEnd) else {throw UFitRefundProofFailure.file}
    }
    private enum Signature {static let pdf = Data("%PDF-".utf8), jpeg = Data([0xff, 0xd8, 0xff]), jpegEnd = Data([0xff, 0xd9])}
}
struct UFitRefundProofRequest: Codable {
    let requestId: String
    let expectedVersion: Int
    let transferReference: String
    let transferredOn: String
    let file: UFitRefundProofSelection
    func validate() throws {
        guard UUID(uuidString: requestId) != nil, (UFitRefundOrganizationRules.firstVersion...UFitRefundOrganizationRules.maximumVersion).contains(expectedVersion),
              UFitServerTextInput.valid(transferReference, maximum: UFitRefundProofContract.referenceMaximum), UFitRefundProofContract.dateValue(transferredOn) != nil else {throw UFitRefundProofFailure.local}
        try file.validate()
    }
}

struct UFitRefundProofPresentation {
    let reference: String
    let date: String
}
