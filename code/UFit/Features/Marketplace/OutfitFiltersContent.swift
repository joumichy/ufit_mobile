import SwiftUI

struct UFitOutfitFiltersContent: View {
    @State private var draft: UFitOutfitSearchCriteria
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
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    tagSelection(.style, selection: $draft.styleID, all: Copy.allStyles)
                    tagSelection(.occasion, selection: $draft.occasionID, all: Copy.allOccasions)
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        Text(Copy.pieceType).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                        UFitSelection(Copy.pieceType, selection: $draft.itemType,
                            options: [.init(value: nil, title: Copy.allPieces)] + options.itemTypes.map { .init(value: Optional($0), title: $0.label) })
                    }
                    UFitActionButton(title: Copy.apply, kind: .primary, action: { onApply(draft) })
                    if draft.hasFilters {
                        UFitButton(Copy.reset) { draft.styleID = nil; draft.occasionID = nil; draft.itemType = nil }.ufitButtonStyle(.text)
                    }
                }.padding(UFitSpace.page)
            }.scrollIndicators(.hidden)
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func tagSelection(_ type: UFitOutfitTagType, selection: Binding<String?>, all: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            Text(type.label).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
            UFitSelection(type.label, selection: selection, options: [.init(value: nil, title: all)]
                + options.tags.filter { $0.type == type }.map { .init(value: Optional($0.id), title: $0.label) })
        }
    }
}
