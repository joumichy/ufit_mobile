import SwiftUI

struct UFitCreatorGradeAssignmentDetailContent: View {
    let assignment: UFitCreatorGradeAssignmentPresentation
    let history: [UFitCreatorGradeChangePresentation]
    let hasLoadedHistory: Bool
    let isLoading: Bool
    let hasMore: Bool
    let message: String?
    let canChangeGrade: Bool
    let ineligibilityMessage: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onChangeGrade: () -> Void
    let onMore: () -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: CreatorGradePresentationCopy.assignments, onBack: onBack) {
                UFitButton(action: onRefresh) { UFitIcon(systemName: CreatorGradePresentationCopy.refreshSymbol) }
                    .disabled(isLoading).accessibilityLabel(UFitCreatorGradeAdminCopy.refresh)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    UFitCreatorGradeAssignmentFacts(assignment: assignment)
                    if canChangeGrade { UFitActionButton(title: CreatorGradePresentationCopy.change, disabled: isLoading, action: onChangeGrade) }
                    else if let ineligibilityMessage { UFitNotice(message: ineligibilityMessage) }
                    Divider()
                    Text(UFitCreatorGradeAdminCopy.history).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                    if let message {
                        UFitNotice(message: message, kind: .error)
                        UFitActionButton(title: UFitCreatorGradeAdminCopy.retry, kind: .secondary, disabled: isLoading, action: onRefresh)
                    }
                    if history.isEmpty {
                        if isLoading || (!hasLoadedHistory && message == nil) { UFitLoading(CreatorGradePresentationCopy.loadingHistory).frame(maxWidth: .infinity) }
                        else if hasLoadedHistory && message == nil { UFitEmptyState(title: CreatorGradePresentationCopy.noHistory, symbol: CreatorGradePresentationCopy.historySymbol) }
                    } else {
                        ForEach(history) { change in
                            VStack(alignment: .leading, spacing: UFitSpace.md) {
                                if let version = change.version { Text(CreatorGradePresentationCopy.version(version)).font(UFitTypography.headline) }
                                Text(change.sourceLabel ?? CreatorGradePresentationCopy.sourceUnknown).font(UFitTypography.subheadline)
                                Text(change.recordedAt).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                if let fromCode = change.fromGradeCode {
                                    historyGrade(CreatorGradePresentationCopy.previousGrade, code: fromCode, label: change.fromGradeLabel)
                                }
                                historyGrade(CreatorGradePresentationCopy.attributedGrade, code: change.toGradeCode, label: change.toGradeLabel)
                                if let reason = change.reason { Text(reason).font(UFitTypography.callout).fixedSize(horizontal: false, vertical: true) }
                                if let actorID = change.actorID {
                                    UFitDisclosure(CreatorGradePresentationCopy.actor) { Text(actorID).font(UFitTypography.caption).textSelection(.enabled) }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                        }
                        if isLoading { UFitLoading().frame(maxWidth: .infinity) }
                        if hasMore { UFitActionButton(title: UFitCreatorGradeAdminCopy.more, kind: .secondary, disabled: isLoading, action: onMore) }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func historyGrade(_ title: String, code: String, label: String?) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xxs) {
            Text(title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            if let label { Text(label).font(UFitTypography.subheadline) }
            Text(code).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText).textSelection(.enabled)
        }
    }
}
