import SwiftUI

struct UFitOutfitFiltersContent: View {
    @State private var draft: UFitOutfitSearchCriteria
    @State private var pieceSearch = String()
    @Environment(\.dynamicTypeSize) private var typeSize
    let options: UFitOutfitDiscoveryOptions
    let onApply: (UFitOutfitSearchCriteria) -> Void
    let onClose: () -> Void
    private typealias Copy = UFitOutfitSearchCopy
    init(initial: UFitOutfitSearchCriteria, options: UFitOutfitDiscoveryOptions,
         onApply: @escaping (UFitOutfitSearchCriteria) -> Void, onClose: @escaping () -> Void) {
        _draft = State(initialValue: initial); self.options = options; self.onApply = onApply; self.onClose = onClose
    }
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: Copy.filters, onClose: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    tagSelection(.style, selection: $draft.styleID)
                    Divider()
                    tagSelection(.occasion, selection: $draft.occasionID)
                    Divider()
                    VStack(alignment: .leading, spacing: UFitSpace.sm) {
                        Text(Copy.pieceType).font(UFitTypography.headline).accessibilityAddTraits(.isHeader)
                        UFitDisclosure(draft.itemType?.label ?? Copy.allPieces, initiallyExpanded: draft.itemType != nil) {
                            VStack(alignment: .leading, spacing: UFitSpace.md) {
                                UFitSearchField(query: $pieceSearch)
                                pieceChoices
                            }
                        }
                    }
                }.padding(UFitSpace.page)
            }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(spacing: UFitSpace.xs) { apply; reset }
                } else {
                    HStack(spacing: UFitSpace.sm) { reset.fixedSize(); apply }
                }
            }.padding(.horizontal, UFitSpace.page).padding(.vertical, UFitSpace.md).background(Color.ufitCanvas)
                .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func tagSelection(_ type: UFitOutfitTagType, selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.sm) {
            Text(type.label).font(UFitTypography.headline).accessibilityAddTraits(.isHeader)
            UFitFilterChoices(title: type.label, selection: selection, options: [.init(value: nil, title: Copy.allFilterValues)]
                + options.tags.filter { $0.type == type }.map { .init(value: Optional($0.id), title: $0.label) })
        }
    }
    private var apply: some View {
        UFitActionButton(title: Copy.apply, kind: .primary, action: { onApply(draft) })
    }
    private var reset: some View {
        UFitButton(Copy.resetShort) {
            draft.styleID = nil; draft.occasionID = nil; draft.itemType = nil; pieceSearch = String()
        }.ufitButtonStyle(.secondary).disabled(!draft.hasFilters).accessibilityLabel(Copy.reset)
    }
    private var pieceChoices: some View {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
            UFitChoiceChip(selected: draft.itemType == nil, action: { draft.itemType = nil }) {
                Text(Copy.allPieces)
            }
            if filteredPieces.isEmpty { UFitEmptyState(title: UFitFeedbackCopy.empty) }
            ForEach(UFitOutfitItemType.Group.allCases) { group in
                let types = filteredPieces.filter { $0.group == group }
                if !types.isEmpty {
                    VStack(alignment: .leading, spacing: UFitSpace.sm) {
                        Text(group.label).font(UFitTypography.subheadline.weight(.medium)).accessibilityAddTraits(.isHeader)
                        FlowLayout(spacing: UFitSpace.xs) {
                            ForEach(types) { type in
                                UFitChoiceChip(selected: draft.itemType == type, action: { draft.itemType = type }) {
                                    HStack(spacing: UFitSpace.xs) { UFitOutfitItemIcon(type: type); Text(type.label) }
                                }.accessibilityLabel(type.label)
                            }
                        }
                    }
                }
            }
        }
    }
    private var filteredPieces: [UFitOutfitItemType] {
        options.itemTypes.filter {
            pieceSearch.isEmpty || $0.label.localizedStandardContains(pieceSearch) || $0.group.label.localizedStandardContains(pieceSearch)
        }
    }
}
