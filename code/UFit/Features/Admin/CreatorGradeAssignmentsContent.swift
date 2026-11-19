import SwiftUI

struct UFitCreatorGradeAssignmentsContent: View {
    let assignments: [UFitCreatorGradeAssignmentPresentation]
    @Binding var search: String
    let hasLoaded: Bool
    let isLoading: Bool
    let hasMore: Bool
    let openingIDs: Set<String>
    let message: String?
    let onBack: () -> Void
    let onDefinitions: () -> Void
    let onSearch: () -> Void
    let onReset: () -> Void
    let onOpen: (String) -> Void
    let onMore: () -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitCreatorGradeAdminCopy.title, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    UFitChoiceBar(title: CreatorGradePresentationCopy.section,
                        selection: Binding<UFitCreatorGradeAdministrationSection>(get: { .assignments }, set: { if $0 == .definitions { onDefinitions() } }),
                        options: CreatorGradePresentationCopy.sectionOptions)
                    UFitSearchField(query: $search, prompt: CreatorGradePresentationCopy.searchCreator).onSubmit(onSearch)
                    UFitButton(CreatorGradePresentationCopy.search, action: onSearch).ufitButtonStyle(.secondary).disabled(isLoading)
                    if !assignments.isEmpty, let message {
                        UFitNotice(message: message, kind: .error)
                        UFitActionButton(title: UFitCreatorGradeAdminCopy.retry, kind: .secondary, disabled: isLoading, action: onSearch)
                    }
                    if assignments.isEmpty { empty }
                    else {
                        LazyVStack(spacing: .zero) {
                            ForEach(assignments) { assignment in
                                UFitButton { onOpen(assignment.id) } label: {
                                    HStack(alignment: .top, spacing: UFitSpace.md) {
                                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                            Text(assignment.displayName).font(UFitTypography.headline)
                                            Text(assignment.slug).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                            Text(assignment.gradeLabel).font(UFitTypography.subheadline)
                                            UFitLabeledValue(CreatorGradePresentationCopy.profile, value: assignment.creatorStatus.label).font(UFitTypography.caption)
                                            if assignment.accountStatus != .active {
                                                UFitLabeledValue(CreatorGradePresentationCopy.account, value: assignment.accountStatus.label).font(UFitTypography.caption)
                                            }
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        if openingIDs.contains(assignment.id) { UFitLoading() }
                                        else { UFitIcon(systemName: CreatorGradePresentationCopy.nextSymbol).font(UFitTypography.caption).accessibilityHidden(true) }
                                    }.padding(.vertical, UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
                                }.disabled(openingIDs.contains(assignment.id))
                                Divider()
                            }
                        }
                        if isLoading { UFitLoading().frame(maxWidth: .infinity) }
                        if hasMore { UFitActionButton(title: UFitCreatorGradeAdminCopy.more, kind: .secondary, disabled: isLoading, action: onMore) }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
                .ufitRefreshable(isEnabled: !isLoading, title: UFitCreatorGradeAdminCopy.refresh) { onSearch() }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    @ViewBuilder private var empty: some View {
        if let message {
            UFitEmptyState(title: CreatorGradePresentationCopy.assignmentsUnavailable, message: message, symbol: CreatorGradePresentationCopy.errorSymbol,
                actionTitle: UFitCreatorGradeAdminCopy.retry, action: onSearch)
        } else if isLoading || !hasLoaded { UFitLoading(CreatorGradePresentationCopy.loadingAssignments).frame(maxWidth: .infinity) }
        else {
            UFitEmptyState(title: search.isEmpty ? CreatorGradePresentationCopy.emptyAssignments : CreatorGradePresentationCopy.emptyAssignmentsSearch,
                symbol: CreatorGradePresentationCopy.creatorSymbol, actionTitle: search.isEmpty ? nil : CreatorGradePresentationCopy.clear,
                action: search.isEmpty ? nil : onReset)
        }
    }
}
