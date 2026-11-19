import Foundation

extension UFitCreatorGradeAssignmentDTO {
    var presentation: UFitCreatorGradeAssignmentPresentation {
        .init(id: creatorId, displayName: displayName, slug: slug, creatorStatus: creatorStatus, accountStatus: accountStatus,
            gradeCode: gradeCode, gradeLabel: gradeLabel, gradeRank: gradeRank, version: version)
    }
    var ineligibilityMessage: String? {
        if accountStatus != .active { return Copy.inactiveAccount }
        if creatorStatus != .active && creatorStatus != .paused { return Copy.inactiveCreator }
        return nil
    }
    private enum Copy {
        static let inactiveAccount = String(localized: "Le compte doit être actif pour changer son grade.")
        static let inactiveCreator = String(localized: "Le profil créateur doit être actif ou en pause pour changer son grade.")
    }
}

extension UFitCreatorGradeChangeDTO {
    var presentation: UFitCreatorGradeChangePresentation {
        let sourceLabel: String?
        switch source {
        case .application: sourceLabel = CreatorGradePresentationCopy.sourceApplication
        case .administration: sourceLabel = CreatorGradePresentationCopy.sourceAdministration
        case nil: sourceLabel = nil
        }
        return .init(id: id, version: version, sourceLabel: sourceLabel, fromGradeCode: fromGradeCode, fromGradeLabel: fromGradeLabel,
            toGradeCode: toGradeCode, toGradeLabel: toGradeLabel, actorID: changedByUserId, reason: reason,
            recordedAt: createdAt.value.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(Format.locale)))
    }
    private enum Format { static let locale = Locale(identifier: "fr_CH") }
}
