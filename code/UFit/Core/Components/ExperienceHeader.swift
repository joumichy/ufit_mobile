import SwiftUI

struct UFitExperienceHeader: View {
    let title: String
    let name: String
    let kind: UFitExperienceKind
    let onChooseExperience: () -> Void
    var isLoading = false
    private enum Copy { static let choose = String(localized: "Changer d’espace") }
    private enum Icon { static let choose = "chevron.down" }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let title: CGFloat = UFitTypography.Size.display; static let gap: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            HStack(alignment: .center) {
                UFitButton(action: onChooseExperience) {
                    HStack(spacing: Layout.gap) {
                        Text(name).font(UFitTypography.subheadline.weight(.medium)).lineLimit(1)
                        UFitIcon(systemName: Icon.choose).font(UFitTypography.caption.weight(.semibold))
                    }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                }.accessibilityLabel(Copy.choose).accessibilityValue(name == kind.title ? name : name + TextSeparator.value + kind.title)
                Spacer(minLength: Layout.gap)
                if isLoading { UFitLoading().frame(width: Layout.touch, height: Layout.touch) }
            }
            Text(title).ufitFont(size: Layout.title, weight: .regular, design: .serif).accessibilityAddTraits(.isHeader)
        }.padding(.horizontal, Layout.page).padding(.top, Layout.gap).padding(.bottom, Layout.page)
            .foregroundStyle(Color.ufitInk).ufitButtonStyle(.text)
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
    private enum Layout { static let gap: CGFloat = UFitSpace.sm; static let small: CGFloat = UFitSpace.xxs; static let touch: CGFloat = UFitControlSize.input; static let icon: CGFloat = 22 }
    private enum Icon { static let next = "chevron.right" }
    var body: some View {
        UFitButton(action: action) {
            HStack(spacing: Layout.gap) {
                if let systemImage { UFitIcon(systemName: systemImage).frame(width: Layout.icon).accessibilityHidden(true) }
                VStack(alignment: .leading, spacing: Layout.small) {
                    Text(title).font(UFitTypography.body)
                    if let subtitle { Text(subtitle).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Layout.small)
                if let count { Text(count, format: .number).font(UFitTypography.body.monospacedDigit()).foregroundStyle(Color.ufitSecondaryText) }
                if isBusy { UFitLoading() }
                else { UFitIcon(systemName: Icon.next).font(UFitTypography.caption.weight(.semibold)).foregroundStyle(Color.ufitSecondaryText).accessibilityHidden(true) }
            }.frame(minHeight: Layout.touch).contentShape(Rectangle())
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).disabled(isBusy)
    }
}

struct UFitEditorialHeading: View {
    let title: String
    var eyebrow: String? = nil
    var message: String? = nil
    var editorial = true
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            if let eyebrow { Text(eyebrow).font(UFitTypography.caption.weight(.medium)).textCase(.uppercase).tracking(HeadingLayout.tracking).foregroundStyle(Color.ufitSecondaryText) }
            Text(title).ufitFont(size: editorial ? UFitTypography.Size.editorial : UFitTypography.Size.section, weight: editorial ? .regular : .medium, design: editorial ? .serif : .default).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).fixedSize(horizontal: false, vertical: true) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
private enum HeadingLayout { static let tracking: CGFloat = 1.2 }
