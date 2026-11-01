import SwiftUI

struct UFitExperienceHeader: View {
    let title: String
    let name: String
    let kind: UFitExperienceKind
    let onChooseExperience: () -> Void
    var onRefresh: (() -> Void)?
    var isLoading = false
    private enum Copy { static let choose = String(localized: "Changer d’espace"); static let refresh = String(localized: "Actualiser") }
    private enum Icon { static let choose = "chevron.down"; static let refresh = "arrow.clockwise" }
    private enum Layout {
        static let page: CGFloat = 24; static let title: CGFloat = 34; static let gap: CGFloat = 8; static let touch: CGFloat = 44
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            HStack(alignment: .center) {
                Button(action: onChooseExperience) {
                    HStack(spacing: Layout.gap) {
                        Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                        Image(systemName: Icon.choose).font(.caption.weight(.semibold))
                    }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                }.accessibilityLabel(Copy.choose).accessibilityValue(name + TextSeparator.value + kind.title)
                Spacer(minLength: Layout.gap)
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else if let onRefresh { Button(action: onRefresh) { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }
            Text(title).font(.system(size: Layout.title, weight: .regular, design: .serif)).accessibilityAddTraits(.isHeader)
        }.padding(.horizontal, Layout.page).padding(.top, Layout.gap).padding(.bottom, Layout.page)
            .foregroundStyle(Color.ufitInk).buttonStyle(.plain)
    }
    private enum TextSeparator { static let value = " · " }
}

struct UFitExperienceActionRow: View {
    let title: String
    var subtitle: String?
    var count: Int?
    var systemImage: String?
    var isBusy = false
    let action: () -> Void
    private enum Layout { static let gap: CGFloat = 12; static let small: CGFloat = 4; static let touch: CGFloat = 52; static let icon: CGFloat = 22 }
    private enum Icon { static let next = "chevron.right" }
    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.gap) {
                if let systemImage { Image(systemName: systemImage).frame(width: Layout.icon).accessibilityHidden(true) }
                VStack(alignment: .leading, spacing: Layout.small) {
                    Text(title).font(.body)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Color.ufitMuted) }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Layout.small)
                if let count { Text(count, format: .number).font(.body.monospacedDigit()).foregroundStyle(Color.ufitMuted) }
                if isBusy { ProgressView() }
                else { Image(systemName: Icon.next).font(.caption.weight(.semibold)).foregroundStyle(Color.ufitMuted).accessibilityHidden(true) }
            }.frame(minHeight: Layout.touch).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(Color.ufitInk).disabled(isBusy)
    }
}
