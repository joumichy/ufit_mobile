import Foundation

enum UFitSavedOutfitState: Equatable {
    case unknown, checking, saved, notSaved, updating(Bool), unconfirmed(Bool)
    var isBusy: Bool {
        switch self { case .checking, .updating: true; default: false }
    }
    var confirmedValue: Bool? {
        switch self { case .saved: true; case .notSaved: false; default: nil }
    }
    var actionLabel: String {
        switch self {
        case .unknown, .unconfirmed: Copy.verify
        case .checking: Copy.checking
        case .saved: Copy.remove
        case .notSaved: Copy.save
        case .updating(let saved): saved ? Copy.saving : Copy.removing
        }
    }
    var symbol: String {
        switch self {
        case .saved: Icon.saved
        case .unknown, .unconfirmed: Icon.verify
        default: Icon.bookmark
        }
    }
    private enum Copy {
        static let verify = String(localized: "Vérifier le favori")
        static let checking = String(localized: "Vérification du favori")
        static let save = String(localized: "Sauvegarder la tenue")
        static let remove = String(localized: "Retirer des favoris")
        static let saving = String(localized: "Enregistrement")
        static let removing = String(localized: "Retrait des favoris")
    }
    private enum Icon { static let saved = "bookmark.fill"; static let bookmark = "bookmark"; static let verify = "arrow.clockwise" }
}
