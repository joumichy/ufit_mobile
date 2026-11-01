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
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 4; static let title: CGFloat = 30; static let touch: CGFloat = 52; static let icon: CGFloat = 24 }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.page) {
            HStack {
                Text(Copy.title).font(.system(size: Layout.title, design: .serif))
                Spacer()
                Button(action: onClose) { Image(systemName: Icon.close).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.close)
            }
            if isLoading { ProgressView(Copy.loading) }
            if let message {
                Text(message).font(.callout).foregroundStyle(Color.ufitMuted)
                Button(Copy.refresh, action: onRefresh).frame(minHeight: Layout.touch)
            }
            ScrollView {
                VStack(spacing: .zero) {
                    ForEach(choices) { choice in
                        Button { onChoose(choice.selection) } label: {
                            HStack(spacing: Layout.gap) {
                                Image(systemName: choice.selection.kind.systemImage).font(.title3).frame(width: Layout.icon).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: Layout.small) {
                                    Text(choice.name.isEmpty ? choice.selection.kind.title : choice.name).font(.body.weight(.medium))
                                    if !choice.name.isEmpty { Text(choice.selection.kind.title).font(.caption).foregroundStyle(Color.ufitMuted) }
                                    if let status = choice.status, status != .active { Text(status.label).font(.caption).foregroundStyle(Color.ufitMuted) }
                                }.fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: Layout.small)
                                if selected == choice.selection { Image(systemName: Icon.selected).accessibilityHidden(true) }
                            }.frame(minHeight: Layout.touch).padding(.vertical, Layout.gap).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(!choice.canSelect)
                            .accessibilityAddTraits(selected == choice.selection ? .isSelected : [])
                        Divider()
                    }
                }
            }
        }.padding(Layout.page).foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
