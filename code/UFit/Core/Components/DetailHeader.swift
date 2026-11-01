import SwiftUI

struct DetailHeader<Trailing: View>: View {
    let title: String?
    let onBack: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String? = nil,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing
    }

    @Environment(\.ufitPrimarySection) private var isPrimarySection
    var body: some View {
        HStack {
            if !isPrimarySection {
                UFitButton(action: onBack) {
                    UFitIcon(systemName: DetailHeaderIcon.back).ufitFont(size: DetailHeaderLayout.icon, weight: .medium)
                        .foregroundStyle(Color.ufitInk).frame(width: DetailHeaderLayout.touch, height: DetailHeaderLayout.touch)
                }.ufitButtonStyle(.text).accessibilityLabel(DetailHeaderCopy.back)
            }
            if let title {
                Text(title)
                    .ufitFont(size: isPrimarySection ? DetailHeaderLayout.sectionTitle : DetailHeaderLayout.title, weight: isPrimarySection ? .regular : .medium, design: isPrimarySection ? .serif : .default)
                    .foregroundStyle(Color.ufitInk).accessibilityAddTraits(.isHeader)
            }
            Spacer()
            trailing()
        }.padding(.horizontal, isPrimarySection ? DetailHeaderLayout.sectionHorizontal : DetailHeaderLayout.horizontal)
            .padding(.vertical, isPrimarySection ? DetailHeaderLayout.sectionVertical : DetailHeaderLayout.vertical)
            .background(.white.opacity(DetailHeaderLayout.opacity))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.ufitBorder).frame(height: DetailHeaderLayout.border) }
    }
}
private struct UFitPrimarySectionKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var ufitPrimarySection: Bool {
        get {self[UFitPrimarySectionKey.self]}
        set {self[UFitPrimarySectionKey.self] = newValue}
    }
}

private enum DetailHeaderLayout {
        static let icon: CGFloat = 22; static let touch: CGFloat = UFitControlSize.touch; static let title: CGFloat = UFitTypography.Size.heading; static let sectionTitle: CGFloat = UFitTypography.Size.editorial
        static let horizontal: CGFloat = 14; static let sectionHorizontal: CGFloat = UFitSpace.xl; static let vertical: CGFloat = 7; static let sectionVertical: CGFloat = UFitSpace.md; static let border: CGFloat = UFitSpace.hairline
        static let opacity = 0.95
    }
private enum DetailHeaderCopy { static let back = String(localized: "Retour") }
private enum DetailHeaderIcon { static let back = "chevron.left" }
