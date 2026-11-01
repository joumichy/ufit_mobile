import Foundation
import Observation

@MainActor @Observable
final class UFitManagedProfileStore {
    private(set) var document: UFitManagedProfileDocument
    var draft: UFitManagedProfileDraft {
        didSet { if !isBusy { message = nil; errors = [:] } }
    }
    private(set) var errors = [UFitProfileField: String]()
    private(set) var isBusy = false
    private(set) var message: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let ownerUserID: String?
    private enum Contract {
        static let nameMin = 2; static let creatorNameMax = 80; static let brandNameMax = 120; static let bioMax = 1000; static let handleMin = 1; static let handleMax = 120
        static let http = "http"; static let https = "https"
    }
    private enum Copy {
        static let creatorName = String(localized: "Saisissez entre 2 et 80 caractères.")
        static let brandName = String(localized: "Saisissez entre 2 et 120 caractères.")
        static let bio = String(localized: "La bio peut contenir jusqu’à 1 000 caractères.")
        static let handle = String(localized: "Saisissez un identifiant de 1 à 120 caractères.")
        static let url = String(localized: "Saisissez un lien HTTP ou HTTPS complet.")
        static let invalid = String(localized: "Vérifiez les champs indiqués avant l’enregistrement.")
        static let success = String(localized: "Profil enregistré.")
    }
    init(document: UFitManagedProfileDocument, client: UFitAPIClient, session: UFitSessionStore) {
        self.document = document; self.draft = document.draft; self.client = client; self.session = session; ownerUserID = session.user?.id
    }
    var hasChanges: Bool { draft != document.draft }
    func save() async {
        guard !isBusy, hasChanges, document.draft.status.canEdit, let userID = session.user?.id, userID == ownerUserID else { return }
        draft.name = trimmed(draft.name); draft.bio = trimmed(draft.bio); draft.website = trimmed(draft.website)
        draft.socials = draft.socials.map { UFitSocialDraft(platform: $0.platform, handle: trimmed($0.handle), url: trimmed($0.url)) }
        validate()
        guard errors.isEmpty else { message = Copy.invalid; return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let result = try await client.saveManagedProfile(document, draft: draft, userID: userID)
            guard session.user?.id == userID else { return }
            document = result; draft = result.draft; message = Copy.success
        } catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func validURL(_ text: String) -> Bool {
        guard !text.isEmpty else { return true }
        guard !text.contains(where: { $0.isWhitespace }), let url = URL(string: text), let scheme = url.scheme, [Contract.http, Contract.https].contains(scheme.lowercased()),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return false }
        return true
    }
    private func validate() {
        errors = [:]
        if !(Contract.nameMin...(document.isCreator ? Contract.creatorNameMax : Contract.brandNameMax)).contains(draft.name.unicodeScalars.count) { errors[.name] = document.isCreator ? Copy.creatorName : Copy.brandName }
        if draft.bio.unicodeScalars.count > Contract.bioMax { errors[.bio] = Copy.bio }
        if !document.isCreator && !validURL(draft.website) { errors[.website] = Copy.url }
        for social in draft.socials {
            if !(Contract.handleMin...Contract.handleMax).contains(social.handle.unicodeScalars.count) { errors[.handle(social.platform)] = Copy.handle }
            if !validURL(social.url) { errors[.socialURL(social.platform)] = Copy.url }
        }
    }
}
