import SwiftUI

struct UFitCreatorGradesContent: View {
    let grades: [UFitCreatorGradeRow]
    @Binding var search: String
    @Binding var assignable: Bool?
    let hasLoaded: Bool
    let isLoading: Bool
    let hasMore: Bool
    let openingIDs: Set<String>
    let message: String?
    let onBack: () -> Void
    let onAssignments: () -> Void
    let onSearch: () -> Void
    let onReset: () -> Void
    let onCreate: () -> Void
    let onOpen: (String) -> Void
    let onMore: () -> Void
    private var filtered: Bool { !search.isEmpty || assignable != nil }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitCreatorGradeAdminCopy.title, onBack: onBack) {
                UFitButton(action: onSearch) { UFitIcon(systemName: CreatorGradePresentationCopy.refreshSymbol) }
                    .disabled(isLoading).accessibilityLabel(UFitCreatorGradeAdminCopy.refresh)
                if !grades.isEmpty || filtered || !hasLoaded || message != nil || isLoading {
                    UFitButton(action: onCreate) { UFitIcon(systemName: CreatorGradePresentationCopy.addSymbol) }
                        .accessibilityLabel(UFitCreatorGradeAdminCopy.create)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    UFitChoiceBar(title: CreatorGradePresentationCopy.section,
                        selection: Binding<UFitCreatorGradeAdministrationSection>(get: { .definitions }, set: { if $0 == .assignments { onAssignments() } }),
                        options: CreatorGradePresentationCopy.sectionOptions)
                    VStack(spacing: UFitSpace.md) {
                        UFitSearchField(query: $search, prompt: UFitCreatorGradeAdminCopy.search).onSubmit(onSearch)
                        UFitSelection(CreatorGradePresentationCopy.availability, selection: $assignable, options: CreatorGradePresentationCopy.availabilityOptions)
                        UFitButton(CreatorGradePresentationCopy.search, action: onSearch).ufitButtonStyle(.secondary).disabled(isLoading)
                    }
                    if !grades.isEmpty, let message {
                        UFitNotice(message: message, kind: .error)
                        UFitActionButton(title: UFitCreatorGradeAdminCopy.retry, kind: .secondary, disabled: isLoading, action: onSearch)
                    }
                    if grades.isEmpty { empty }
                    else {
                        LazyVStack(spacing: .zero) {
                            ForEach(grades) { grade in
                                UFitButton { onOpen(grade.id) } label: {
                                    HStack(alignment: .top, spacing: UFitSpace.md) {
                                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                            Text(grade.label).font(UFitTypography.headline)
                                            Text(grade.id).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                            UFitLabeledValue(UFitCreatorGradeAdminCopy.rank) { Text(grade.rank, format: .number) }.font(UFitTypography.subheadline)
                                            Text(grade.assignable ? UFitCreatorGradeAdminCopy.assignable : UFitCreatorGradeAdminCopy.unavailable).font(UFitTypography.caption)
                                            if grade.isInitial { Text(UFitCreatorGradeAdminCopy.initial).font(UFitTypography.caption) }
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        if openingIDs.contains(grade.id) { UFitLoading() }
                                        else { UFitIcon(systemName: CreatorGradePresentationCopy.nextSymbol).font(UFitTypography.caption).accessibilityHidden(true) }
                                    }.padding(.vertical, UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
                                }.disabled(openingIDs.contains(grade.id))
                                Divider()
                            }
                        }
                        if isLoading { UFitLoading().frame(maxWidth: .infinity) }
                        if hasMore { UFitActionButton(title: UFitCreatorGradeAdminCopy.more, kind: .secondary, disabled: isLoading, action: onMore) }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    @ViewBuilder private var empty: some View {
        if let message {
            UFitEmptyState(title: CreatorGradePresentationCopy.unavailable, message: message, symbol: CreatorGradePresentationCopy.errorSymbol,
                actionTitle: UFitCreatorGradeAdminCopy.retry, action: onSearch)
        } else if isLoading || !hasLoaded { UFitLoading(CreatorGradePresentationCopy.loading).frame(maxWidth: .infinity) }
        else {
            UFitEmptyState(title: filtered ? CreatorGradePresentationCopy.emptyDefinitionsSearch : CreatorGradePresentationCopy.emptyDefinitions,
                symbol: CreatorGradePresentationCopy.emptySymbol,
                actionTitle: filtered ? CreatorGradePresentationCopy.clear : UFitCreatorGradeAdminCopy.create,
                actionKind: filtered ? .secondary : .primary, action: filtered ? onReset : onCreate)
        }
    }
}
