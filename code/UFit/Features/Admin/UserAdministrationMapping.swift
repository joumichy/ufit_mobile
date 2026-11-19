import Foundation

extension UFitAdministeredUserDTO {
    func allows(_ decision: UFitUserAccessDecision) -> Bool {
        switch decision {
        case .suspend: actions.suspend
        case .activate: actions.activate
        case .grantAdmin: actions.grantAdmin
        case .revokeAdmin: actions.revokeAdmin
        }
    }
}

extension UFitAdministeredUserDTO {
    var row: UFitAdministeredUserRow {
        .init(id: id, email: email, displayName: displayName, status: status, roles: roles, version: version)
    }
    var document: UFitAdministeredUserDocument {
        .init(user: row, createdAt: createdAt.label, updatedAt: updatedAt.label,
              decisions: UFitUserAccessDecision.allCases.filter { allows($0) })
    }
}
extension UFitUserAccessChangeDTO {
    var row: UFitUserAccessHistoryRow {
        let decision: UFitUserAccessDecision
        switch kind {
        case .status: decision = toStatus == .active ? .activate : .suspend
        case .adminAccess: decision = adminAfter ? .grantAdmin : .revokeAdmin
        }
        return .init(id: id, version: version, decision: decision, reason: reason,
                     date: createdAt.value.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(Format.locale)), actorID: decidedByUserId)
    }
    private enum Format { static let locale = Locale(identifier: "fr_CH") }
}
