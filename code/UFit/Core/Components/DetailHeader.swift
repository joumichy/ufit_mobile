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
                Button(action: onBack) {
                    Image(systemName: DetailHeaderIcon.back).font(.system(size: DetailHeaderLayout.icon, weight: .medium))
                        .foregroundStyle(Color.ufitInk).frame(width: DetailHeaderLayout.touch, height: DetailHeaderLayout.touch)
                }.buttonStyle(.plain).accessibilityLabel(DetailHeaderCopy.back)
            }
            if let title {
                Text(title)
                    .font(isPrimarySection ? .system(size: DetailHeaderLayout.sectionTitle, weight: .regular, design: .serif) : .system(size: DetailHeaderLayout.title, weight: .medium))
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
        static let icon: CGFloat = 22; static let touch: CGFloat = 44; static let title: CGFloat = 18; static let sectionTitle: CGFloat = 30
        static let horizontal: CGFloat = 14; static let sectionHorizontal: CGFloat = 24; static let vertical: CGFloat = 7; static let sectionVertical: CGFloat = 16; static let border: CGFloat = 1
        static let opacity = 0.95
    }
private enum DetailHeaderCopy { static let back = String(localized: "Retour") }
private enum DetailHeaderIcon { static let back = "chevron.left" }
