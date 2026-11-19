import Foundation

enum UFitDistributionCopy {
    static let title = String(localized: "Répartition des ventes"), search = String(localized: "Rechercher une marque")
    static let loading = String(localized: "Chargement des conditions"), loadingBrands = String(localized: "Chargement des marques")
    static let empty = String(localized: "Aucune marque pour cette recherche."), clear = String(localized: "Effacer la recherche")
    static let searchTooLong = String(localized: "Limitez la recherche à 120 caractères.")
    static let unset = String(localized: "À configurer"), emptyTitle = String(localized: "Conditions à définir")
    static let configure = String(localized: "Configurer les conditions"), edit = String(localized: "Modifier les conditions")
    static let platformRate = String(localized: "Part Ufit (%)"), platformShare = String(localized: "Part Ufit")
    static let basis = String(localized: "Sur les pièces, hors livraison et taxes.")
    static let feeBearer = String(localized: "Frais Stripe"), brandBearer = String(localized: "La marque"), platformBearer = String(localized: "Ufit")
    static let brandCost = String(localized: "Les frais Stripe seront déduits de la part de la marque.")
    static let platformCost = String(localized: "Les frais Stripe seront à la charge d’Ufit et peuvent dépasser sa part.")
    static let active = String(localized: "Active"), inactive = String(localized: "Désactivée")
    static let activate = String(localized: "Appliquer aux nouvelles commandes"), reason = String(localized: "Motif de la révision")
    static let future = String(localized: "Les nouvelles commandes gardent ces conditions, même après une révision.")
    static let creatorScope = String(localized: "Les commissions créateur sont configurées séparément.")
    static let history = String(localized: "Versions des conditions"), noHistory = String(localized: "Aucune version enregistrée.")
    static let save = String(localized: "Enregistrer les conditions"), check = String(localized: "Vérifier l’enregistrement")
    static let retrySave = String(localized: "Réessayer l’enregistrement"), refreshReference = String(localized: "Actualiser les conditions")
    static let current = String(localized: "Conditions actuelles"), currentVersion = String(localized: "Version actuelle")
    static let saved = String(localized: "Conditions enregistrées."), superseded = String(localized: "Votre révision a été enregistrée. Une version plus récente la remplace.")
    static let refresh = String(localized: "Actualiser"), retry = String(localized: "Réessayer"), more = String(localized: "Afficher la suite")
    static let changed = String(localized: "Ces conditions ont changé. Actualisez-les avant d’enregistrer. Votre saisie est conservée.")
    static let referenceUpdated = String(localized: "Comparez les conditions actuelles avec votre saisie avant d’enregistrer.")
    static let unconfirmed = String(localized: "L’enregistrement n’a pas pu être confirmé. Vérifiez son statut avant de continuer.")
    static let notRecorded = String(localized: "Aucun enregistrement confirmé. Vous pouvez réessayer la même demande.")
    static let loadFailed = String(localized: "Les conditions sont indisponibles. Réessayez.")
    static let invalid = String(localized: "Les conditions reçues sont incohérentes. Actualisez avant de continuer.")
    static let unavailable = String(localized: "Marque indisponible"), missing = String(localized: "Cette marque n’est plus disponible. Revenez à la liste.")
    static let accessTitle = String(localized: "Accès indisponible"), access = String(localized: "Cet espace n’est plus accessible. Revenez à l’accueil et actualisez vos accès.")
    static let home = String(localized: "Retour à l’accueil"), brands = String(localized: "Retour aux marques")
    static let rateError = String(localized: "Saisissez un taux entre 0 et 100 %, avec deux décimales au maximum.")
    static let bearerError = String(localized: "Choisissez qui supporte les frais Stripe.")
    static let reasonError = String(localized: "Ajoutez un motif de 1 à 500 caractères.")
    static let discardTitle = String(localized: "Abandonner les modifications ?"), discard = String(localized: "Abandonner"), keep = String(localized: "Continuer la modification")
    static let unknownLeave = String(localized: "Quitter la vérification ? La demande peut avoir été enregistrée.")
    static let percentSuffix = String(localized: " %"), icon = "arrow.triangle.branch", nextIcon = "chevron.right", refreshIcon = "arrow.clockwise"
    static let separator = " · ", historyIcon = "clock.arrow.circlepath"
    private static let locale = Locale(identifier: "fr_CH")
    static func percent(_ value: Int) -> String { UFitDecimalInput.text(value, fractionalDigits: UFitDistributionHTTP.rateDigits) + percentSuffix }
    static func revision(_ value: Int) -> String { String(localized: "Version \(value)") }
    static func replaced(_ date: UFitTimestamp) -> String { String(localized: "Remplacée le \(versionDate(date))") }
    static func versionDate(_ date: UFitTimestamp) -> String { date.value.formatted(.dateTime.day().month().hour().minute().locale(locale)) }
    static func consulted(_ date: UFitTimestamp) -> String {
        String(localized: "Consulté le \(date.value.formatted(.dateTime.day().month().hour().minute()))")
    }
}
enum UFitDistributionField: Hashable { case rate, bearer, reason }
struct UFitDistributionDraft: Equatable {
    var rate = String(); var bearer: UFitDistributionFeeBearer?; var active = false; var reason = String()
    init(policy: UFitDistributionRevision?) {
        if let policy { rate = UFitDecimalInput.text(policy.platformRateBps, fractionalDigits: UFitDistributionHTTP.rateDigits); bearer = policy.feeBearer; active = policy.active }
    }
    var rateBps: Int? { UFitDecimalInput.scaledAmount(rate, fractionalDigits: UFitDistributionHTTP.rateDigits, maximum: UFitDistributionHTTP.basisPoints) }
    var errors: [UFitDistributionField: String] {
        var result = [UFitDistributionField: String]()
        if rateBps == nil { result[.rate] = UFitDistributionCopy.rateError }
        if bearer == nil { result[.bearer] = UFitDistributionCopy.bearerError }
        let value = UFitServerTextInput.trimmed(reason)
        if value.isEmpty || value.utf16.count > UFitDistributionHTTP.reasonMaximum { result[.reason] = UFitDistributionCopy.reasonError }
        return result
    }
}
enum UFitDistributionError {
    static func revoked(_ error: Error) -> Bool {
        if case UFitAPIError.authenticationRequired = error { return true }
        guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
        return status == UFitDistributionHTTP.unauthorized || status == UFitDistributionHTTP.forbidden
    }
    static func code(_ error: Error, equals expected: String) -> Bool {
        guard case UFitAPIError.requestFailed(_, _, let code) = error else { return false }; return code == expected
    }
    static func conflict(_ error: Error) -> Bool {
        code(error, equals: UFitDistributionHTTP.conflict) || code(error, equals: UFitDistributionHTTP.reused)
    }
    static func message(_ error: Error) -> String {
        error is UFitDistributionBoundaryFailure ? UFitDistributionCopy.invalid : UFitDistributionCopy.loadFailed
    }
}
