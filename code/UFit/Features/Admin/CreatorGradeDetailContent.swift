import SwiftUI

struct UFitCreatorGradeDetailContent: View {
    let grade: UFitCreatorGradeRow
    let history: [UFitCreatorGradeRevisionRow]
    let hasLoadedHistory: Bool
    let isLoading: Bool
    let hasMore: Bool
    let message: String?
    let canRevise: Bool
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onRevise: () -> Void
    let onMore: () -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: CreatorGradePresentationCopy.definitions, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    UFitCreatorGradeFacts(grade: grade)
                    if canRevise { UFitActionButton(title: CreatorGradePresentationCopy.revise, disabled: isLoading, action: onRevise) }
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
                        ForEach(history) { revision in
                            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                Text(CreatorGradePresentationCopy.version(revision.version)).font(UFitTypography.headline)
                                if revision.isCurrent { Text(CreatorGradePresentationCopy.currentRevision).font(UFitTypography.caption) }
                                Text(revision.recordedAt).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                Text(revision.label).font(UFitTypography.subheadline)
                                UFitLabeledValue(UFitCreatorGradeAdminCopy.rank) { Text(revision.rank, format: .number) }.font(UFitTypography.subheadline)
                                Text(revision.assignable ? UFitCreatorGradeAdminCopy.assignable : UFitCreatorGradeAdminCopy.unavailable).font(UFitTypography.caption)
                                if let reason = revision.reason { Text(reason).font(UFitTypography.callout).fixedSize(horizontal: false, vertical: true) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                        }
                        if isLoading { UFitLoading().frame(maxWidth: .infinity) }
                        if hasMore { UFitActionButton(title: UFitCreatorGradeAdminCopy.more, kind: .secondary, disabled: isLoading, action: onMore) }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !isLoading, title: UFitCreatorGradeAdminCopy.refresh) { onRefresh() }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
