import SwiftUI

/// Visual category palette shared by every piece in the outfit editor.
struct UFitOutfitItemTypePicker: View {
    @Binding var selection: UFitOutfitItemType
    @State private var choosing = false
    private enum Copy { static let title = String(localized: "Type de pièce") }
    private enum Icon { static let change = "chevron.down" }
    var body: some View {
        UFitButton { choosing = true } label: {
            HStack(spacing: UFitSpace.md) {
                UFitOutfitItemIcon(type: selection)
                Text(selection.label).font(UFitTypography.body).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: UFitSpace.xs)
                UFitIcon(systemName: Icon.change).font(UFitTypography.caption).accessibilityHidden(true)
            }.padding(UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.input)
                .background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.field))
                .overlay { RoundedRectangle(cornerRadius: UFitRadius.field).stroke(Color.ufitBorder, lineWidth: UFitSpace.hairline) }
        }.ufitButtonStyle(.text).accessibilityLabel(Copy.title).accessibilityValue(selection.label)
            .ufitSheet(isPresented: $choosing) {
                UFitOutfitItemTypePalette(selection: selection, onSelect: { selection = $0; choosing = false }, onClose: { choosing = false })
                    .presentationDetents([.large])
            }
    }
}

struct UFitOutfitItemTypePalette: View {
    let selection: UFitOutfitItemType?
    let onSelect: (UFitOutfitItemType) -> Void
    let onClose: () -> Void
    var context: String? = nil
    @State private var search = String()
    @Environment(\.dynamicTypeSize) private var typeSize
    private enum Copy { static let title = String(localized: "Type de pièce") }
    private enum Layout { static let minimumWidth: CGFloat = 94; static let accessibleMinimumWidth: CGFloat = 150; static let height: CGFloat = 90 }
    private var filtered: [UFitOutfitItemType] {
        UFitOutfitItemType.allCases.filter { search.isEmpty || $0.label.localizedStandardContains(search) || $0.group.label.localizedStandardContains(search) }
    }
    private var columns: [GridItem] {
        [.init(.adaptive(minimum: typeSize.isAccessibilitySize ? Layout.accessibleMinimumWidth : Layout.minimumWidth), spacing: UFitSpace.sm)]
    }
    var body: some View {
        VStack(spacing: UFitSpace.md) {
            UFitSheetHeader(title: Copy.title, onClose: onClose)
            if let context { Text(context).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText).padding(.horizontal, UFitSpace.page) }
            UFitSearchField(query: $search).padding(.horizontal, UFitSpace.page)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    if filtered.isEmpty { UFitEmptyState(title: UFitFeedbackCopy.empty) }
                    ForEach(UFitOutfitItemType.Group.allCases) { group in
                        let types = filtered.filter { $0.group == group }
                        if !types.isEmpty {
                            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                Text(group.label).font(UFitTypography.subheadline.weight(.medium)).accessibilityAddTraits(.isHeader)
                                LazyVGrid(columns: columns, spacing: UFitSpace.sm) {
                                    ForEach(types) { type in
                                        UFitButton {
                                            onSelect(type)
                                        } label: {
                                            VStack(spacing: UFitSpace.sm) {
                                                UFitOutfitItemIcon(type: type)
                                                Text(type.label).font(UFitTypography.caption).multilineTextAlignment(.center)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }.padding(UFitSpace.sm).frame(maxWidth: .infinity, minHeight: Layout.height)
                                                .foregroundStyle(selection == type ? Color.ufitCanvas : Color.ufitInk)
                                                .background(selection == type ? Color.ufitInk : Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.field))
                                                .overlay { RoundedRectangle(cornerRadius: UFitRadius.field).stroke(selection == type ? Color.ufitInk : Color.ufitBorder, lineWidth: UFitSpace.hairline) }
                                        }.ufitButtonStyle(.text).accessibilityLabel(type.label)
                                            .accessibilityAddTraits(selection == type ? .isSelected : [])
                                    }
                                }
                            }
                        }
                    }
                }.padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.xl)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
