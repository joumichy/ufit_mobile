import SwiftUI

struct UFitCreatorGradeChoiceContent: View {
    let grades: [UFitCreatorGradeRow]
    @Binding var search: String
    let currentGradeCode: String
    let selectedGradeCode: String?
    let selectableIDs: Set<String>
    let hasLoaded: Bool
    let isLoading: Bool
    let hasMore: Bool
    let message: String?
    let onClose: () -> Void
    let onSearch: () -> Void
    let onReset: () -> Void
    let onChoose: (UFitCreatorGradeRow) -> Void
    let onMore: () -> Void
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: CreatorGradePresentationCopy.chooseGrade, onClose: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    UFitSearchField(query: $search, prompt: UFitCreatorGradeAdminCopy.search).onSubmit(onSearch)
                    UFitButton(CreatorGradePresentationCopy.search, action: onSearch).ufitButtonStyle(.secondary).disabled(isLoading)
                    if !grades.isEmpty, let message {
                        UFitNotice(message: message, kind: .error)
                        UFitActionButton(title: UFitCreatorGradeAdminCopy.retry, kind: .secondary, disabled: isLoading, action: onSearch)
                    }
                    if grades.isEmpty {
                        if let message {
                            UFitEmptyState(title: CreatorGradePresentationCopy.unavailable, message: message, symbol: CreatorGradePresentationCopy.errorSymbol,
                                actionTitle: UFitCreatorGradeAdminCopy.retry, action: onSearch)
                        } else if isLoading || !hasLoaded { UFitLoading(CreatorGradePresentationCopy.loading).frame(maxWidth: .infinity) }
                        else {
                            UFitEmptyState(title: search.isEmpty ? CreatorGradePresentationCopy.emptyChoices : CreatorGradePresentationCopy.emptyDefinitionsSearch,
                                message: search.isEmpty ? CreatorGradePresentationCopy.emptyChoicesMessage : nil,
                                symbol: CreatorGradePresentationCopy.emptySymbol, actionTitle: search.isEmpty ? nil : CreatorGradePresentationCopy.clear,
                                action: search.isEmpty ? nil : onReset)
                        }
                    } else {
                        LazyVStack(spacing: .zero) {
                            ForEach(grades) { grade in
                                UFitButton { onChoose(grade) } label: {
                                    HStack(alignment: .top, spacing: UFitSpace.md) {
                                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                            Text(grade.label).font(UFitTypography.headline)
                                            Text(grade.id).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                            UFitLabeledValue(UFitCreatorGradeAdminCopy.rank) { Text(grade.rank, format: .number) }.font(UFitTypography.subheadline)
                                            if grade.id == currentGradeCode { Text(CreatorGradePresentationCopy.currentGrade).font(UFitTypography.caption) }
                                            else if !grade.assignable { Text(UFitCreatorGradeAdminCopy.unavailable).font(UFitTypography.caption) }
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        if grade.id == selectedGradeCode { UFitIcon(systemName: CreatorGradePresentationCopy.checkSymbol).accessibilityHidden(true) }
                                    }.padding(.vertical, UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
                                }.disabled(!selectableIDs.contains(grade.id)).accessibilityAddTraits(grade.id == selectedGradeCode ? .isSelected : [])
                                Divider()
                            }
                        }
                        if hasLoaded && !hasMore && !isLoading && message == nil && selectableIDs.isEmpty && search.isEmpty {
                            UFitNotice(message: CreatorGradePresentationCopy.emptyChoicesMessage)
                        }
                        if isLoading { UFitLoading().frame(maxWidth: .infinity) }
                        if hasMore { UFitActionButton(title: UFitCreatorGradeAdminCopy.more, kind: .secondary, disabled: isLoading, action: onMore) }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
