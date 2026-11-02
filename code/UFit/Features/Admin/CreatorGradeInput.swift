import Foundation

enum UFitCreatorGradeInput {
    static func errors(_ draft: UFitCreatorGradeDraft, originalCode: String? = nil) -> [UFitCreatorGradeField: String] {
        var result: [UFitCreatorGradeField: String] = [:]
        if !UFitCreatorGradeContract.code(draft.code) { result[.code] = Copy.code }
        if let originalCode {
            if draft.code != originalCode { result[.code] = Copy.immutableCode }
        } else if draft.code == UFitCreatorGradeContract.initialCode { result[.code] = Copy.reservedCode }
        if !UFitServerTextInput.valid(draft.label, maximum: UFitCreatorGradeContract.labelLimit) { result[.label] = Copy.label }
        if rank(draft.rank) == nil { result[.rank] = Copy.rank }
        if !UFitServerTextInput.valid(draft.reason, maximum: UFitCreatorGradeContract.reasonLimit) { result[.reason] = Copy.reason }
        return result
    }
    static func configuration(_ draft: UFitCreatorGradeDraft, originalCode: String? = nil) throws -> UFitCreatorGradeConfiguration {
        guard errors(draft, originalCode: originalCode).isEmpty, let rank = rank(draft.rank) else { throw UFitCreatorGradeFailure.input }
        let result = UFitCreatorGradeConfiguration(label: UFitServerTextInput.trimmed(draft.label), rank: rank, assignable: draft.assignable, reason: UFitServerTextInput.trimmed(draft.reason))
        try result.validate(); return result
    }
    private static func rank(_ text: String) -> Int? {
        guard let value = Int(UFitServerTextInput.trimmed(text)), UFitCreatorGradeContract.integer(value) else { return nil }; return value
    }
    private enum Copy {
        static let code = String(localized: "Utilisez 1 à 80 caractères : une lettre minuscule, puis des lettres minuscules, chiffres ou tirets.")
        static let reservedCode = String(localized: "Ce code appartient au grade initial. Choisissez un autre code.")
        static let immutableCode = String(localized: "Le code du grade ne peut pas changer.")
        static let label = String(localized: "Saisissez un nom de 1 à 120 caractères.")
        static let rank = String(localized: "Saisissez un entier entre 0 et 2 147 483 647.")
        static let reason = String(localized: "Ajoutez un motif de 1 à 500 caractères.")
    }
}
extension UFitCreatorGradeDTO {
    var editingDraft: UFitCreatorGradeDraft { .init(code: code, label: label, rank: String(rank), assignable: assignable, reason: String()) }
    var row: UFitCreatorGradeRow { .init(id: code, label: label, rank: rank, assignable: assignable, isInitial: isInitial, assignedCreators: assignedCreators, version: version) }
}
extension UFitCreatorGradeRevisionDTO {
    func row(currentID: String) -> UFitCreatorGradeRevisionRow {
        .init(id: id, version: version, label: label, rank: rank, assignable: assignable, reason: reason,
              recordedAt: recordedAt.value.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(Format.locale)), isCurrent: id == currentID)
    }
    private enum Format { static let locale = Locale(identifier: "fr_CH") }
}
enum UFitCreatorGradeAdminFailure {
    private enum HTTP { static let unauthorized = 401; static let forbidden = 403; static let conflict = 409; static let unavailable = 500 }
    private enum Copy {
        static let exists = String(localized: "Ce code est déjà utilisé. Consultez le grade existant ou choisissez un autre code.")
    }
    static func conflict(_ error: Error) -> Bool {
        guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
        return status == HTTP.conflict
    }
    static func revoked(_ error: Error) -> Bool {
        guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
        return status == HTTP.unauthorized || status == HTTP.forbidden
    }
    static func uncertain(_ error: Error) -> Bool {
        if case UFitCreatorGradeFailure.input = error { return false }
        if case UFitAPIError.requestFailed(let status, _, _) = error { return status >= HTTP.unavailable }
        return !(error is UFitAPIError)
    }
    static func message(_ error: Error, isNew: Bool = false) -> String {
        if case UFitAPIError.requestFailed(let status, _, _) = error, status == HTTP.conflict { return isNew ? Copy.exists : UFitCreatorGradeAdminCopy.definitionChanged }
        return error.localizedDescription
    }
}
