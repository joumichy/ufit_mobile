import SwiftUI

struct UFitExperienceChooserContent: View {
    let choices: [UFitExperienceChoice]
    let selected: UFitExperienceSelection
    let isLoading: Bool
    let message: String?
    let onChoose: (UFitExperienceSelection) -> Void
    let onRefresh: () -> Void
    let onClose: () -> Void
    private enum Copy {
        static let title = String(localized: "Choisir un espace"); static let refresh = String(localized: "Actualiser les accès"); static let close = String(localized: "Fermer")
        static let loading = String(localized: "Vérification de vos accès")
    }
    private enum Icon { static let close = "xmark"; static let selected = "checkmark.circle.fill" }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xxs; static let title: CGFloat = UFitTypography.Size.editorial; static let touch: CGFloat = UFitControlSize.input; static let icon: CGFloat = 24 }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.page) {
            HStack {
                Text(Copy.title).ufitFont(size: Layout.title, design: .serif)
                Spacer()
                UFitButton(action: onClose) { UFitIcon(systemName: Icon.close).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.close)
            }
            if isLoading { UFitLoading(Copy.loading) }
            if let message {
                Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                UFitActionButton(title: Copy.refresh, kind: .secondary, action: onRefresh)
            }
            ScrollView {
                VStack(spacing: .zero) {
                    ForEach(choices) { choice in
                        UFitButton { onChoose(choice.selection) } label: {
                            HStack(spacing: Layout.gap) {
                                UFitIcon(systemName: choice.selection.kind.systemImage).font(UFitTypography.title3).frame(width: Layout.icon).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: Layout.small) {
                                    Text(choice.name.isEmpty ? choice.selection.kind.title : choice.name).font(UFitTypography.body.weight(.medium))
                                    if !choice.name.isEmpty { Text(choice.selection.kind.title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                                    if let status = choice.status, status != .active { Text(status.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                                }.fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: Layout.small)
                                if selected == choice.selection { UFitIcon(systemName: Icon.selected).accessibilityHidden(true) }
                            }.frame(minHeight: Layout.touch).padding(.vertical, Layout.gap).contentShape(Rectangle())
                        }.ufitButtonStyle(.text).disabled(!choice.canSelect)
                            .accessibilityAddTraits(selected == choice.selection ? .isSelected : [])
                        Divider()
                    }
                }
            }
        }.padding(Layout.page).foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
