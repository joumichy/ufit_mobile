import Foundation

enum UFitProfileImageCopy {
    static let account = String(localized: "Photo du compte")
    static let creator = String(localized: "Portrait créateur")
    static let brand = String(localized: "Logo de la marque")
    static let privatePhoto = String(localized: "Visible uniquement par vous.")
    static let publicPhoto = String(localized: "Visible sur votre profil public lorsqu’il est actif.")
    static let edit = String(localized: "Modifier la photo")
    static let choose = String(localized: "Choisir dans Photos")
    static let replace = String(localized: "Choisir une autre photo")
    static let remove = String(localized: "Retirer la photo")
    static let save = String(localized: "Enregistrer la photo")
    static let confirmRemoval = String(localized: "Confirmer le retrait")
    static let useMine = String(localized: "Utiliser ma photo")
    static let retrySave = String(localized: "Réessayer l’enregistrement")
    static let verify = String(localized: "Vérifier l’enregistrement")
    static let refresh = String(localized: "Actualiser la photo")
    static let retry = String(localized: "Réessayer")
    static let empty = String(localized: "Aucune photo")
    static let loading = String(localized: "Chargement de la photo")
    static let reading = String(localized: "Préparation de la photo")
    static let uploadUnconfirmed = String(localized: "L’envoi de la photo n’est pas confirmé. Réessayez pour reprendre le même envoi.")
    static let uploading = String(localized: "Envoi de la photo")
    static let saving = String(localized: "Enregistrement de la photo")
    static let checking = String(localized: "Vérification de la photo")
    static let saved = String(localized: "Photo enregistrée.")
    static let removed = String(localized: "Photo retirée.")
    static let preview = String(localized: "Aperçu — non enregistré")
    static let removalPreview = String(localized: "La photo sera retirée après confirmation.")
    static let conflict = String(localized: "La photo a changé depuis l’ouverture. Comparez avec la photo actuelle avant de confirmer.")
    static let current = String(localized: "Photo actuelle")
    static let uncertain = String(localized: "L’enregistrement n’est pas confirmé. Vérifiez son état avant de réessayer.")
    static let unchanged = String(localized: "La photo actuelle est inchangée. Vous pouvez réessayer l’enregistrement.")
    static let accepted = String(localized: "Enregistrement reçu. Actualisez pour vérifier la photo actuelle.")
    static let unavailable = String(localized: "La photo ne peut pas être chargée pour le moment.")
    static let connection = String(localized: "Connexion impossible. Vérifiez votre réseau et réessayez.")
    static let close = String(localized: "Fermer")
    static let discardTitle = String(localized: "Quitter la modification de la photo ?")
    static let discard = String(localized: "Quitter")
    static let stay = String(localized: "Continuer")
    static let discardMessage = String(localized: "Votre aperçu non enregistré sera abandonné.")
    static let pendingMessage = String(localized: "Votre photo a peut-être été enregistrée. Vous pourrez vérifier son état en rouvrant cet écran.")
    static let currentUnavailable = String(localized: "La photo actuelle n’est pas disponible. Actualisez avant de continuer.")
    static func title(_ kind: UFitProfileImageScope.Kind) -> String {
        switch kind { case .account: account; case .creator: creator; case .brand: brand }
    }
    static func uploadFailure(_ error: Error) -> String {
        if error is URLError { return uploadUnconfirmed }
        if case UFitAPIError.requestFailed(let status, _, _) = error, status >= UFitProfileImageHTTP.serverFailure { return uploadUnconfirmed }
        return failure(error)
    }
    static func failure(_ error: Error) -> String {
        if error is URLError { return connection }
        if case UFitAPIError.requestFailed(let status, _, _) = error, status >= UFitProfileImageHTTP.serverFailure { return unavailable }
        return error.localizedDescription
    }
}
