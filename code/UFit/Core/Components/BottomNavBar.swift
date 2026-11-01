import SwiftUI

struct BottomNavBar: View {
    let activeTab: AppTab
    var experience: UFitExperienceKind = .customer
    var cartCount: Int = .zero
    let onSelect: (AppTab) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var navigationOpen = false
    @State private var pendingTab: AppTab?
    private enum Copy { static let navigation = String(localized: "Navigation") }
    private enum Layout {
        static let horizontal: CGFloat = UFitSpace.sm; static let top: CGFloat = 10; static let bottom: CGFloat = 10
        static let border: CGFloat = UFitSpace.hairline; static let touch: CGFloat = UFitControlSize.input
    }
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibleNavigation
            } else { tabs }
        }.padding(.horizontal, Layout.horizontal).padding(.top, Layout.top).padding(.bottom, Layout.bottom)
            .background(Color.ufitCanvas.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: Layout.border) }
    }
    private var accessibleNavigation: some View {
        UFitButton { pendingTab = activeTab; navigationOpen = true } label: {
            HStack { Text(activeTab.title).fixedSize(horizontal: false, vertical: true); Spacer(); UFitIcon(systemName: NavigationIcon.choose).font(UFitTypography.caption) }.frame(maxWidth: .infinity)
        }.ufitButtonStyle(.secondary).accessibilityLabel(Copy.navigation).accessibilityValue(activeTab.title)
            .ufitSheet(isPresented: $navigationOpen, onDismiss: {
                let selected = pendingTab; pendingTab = nil
                if let selected, selected != activeTab { onSelect(selected) }
            }) {
                UFitSelectionList(title: Copy.navigation, selection: Binding(get: { pendingTab ?? activeTab }, set: { pendingTab = $0 }),
                    options: experience.tabs.map { .init(value: $0, title: $0.title) }, onClose: { navigationOpen = false })
            }
    }
    private enum NavigationIcon { static let choose = "chevron.down" }
    private var tabs: some View {
        HStack(spacing: .zero) {
            ForEach(experience.tabs) { tab in
                UFitButton { onSelect(tab) } label: {
                    BottomNavItem(tab: tab, isActive: activeTab == tab, count: tab == .cart ? cartCount : .zero)
                }.ufitButtonStyle(.text).frame(maxWidth: .infinity, minHeight: Layout.touch)
                    .accessibilityLabel(tab.title)
                    .accessibilityRemoveTraits(activeTab == tab ? [] : .isSelected)
                    .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
            }
        }
    }
}
struct BottomNavItem: View {
    let tab: AppTab
    let isActive: Bool
    var count: Int = .zero
    private enum Layout {
        static let gap: CGFloat = UFitSpace.xxs; static let icon: CGFloat = 22; static let iconHeight: CGFloat = 24
        static let label: CGFloat = UFitTypography.Size.caption; static let badge: CGFloat = 16; static let offset: CGFloat = 12
    }
    var body: some View {
        VStack(spacing: Layout.gap) {
            UFitIcon(systemName: isActive ? tab.activeSystemImage : tab.systemImage)
                .ufitFont(size: Layout.icon, weight: isActive ? .semibold : .regular)
                .overlay(alignment: .topTrailing) {
                    if count > .zero {
                        Text(count, format: .number).font(UFitTypography.caption2.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, Layout.gap).frame(minWidth: Layout.badge, minHeight: Layout.badge)
                            .background(Color.ufitInk, in: Capsule()).offset(x: Layout.offset, y: -Layout.gap)
                    }
                }
            Text(tab.title).ufitFont(size: Layout.label, weight: isActive ? .semibold : .regular).fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(isActive ? Color.ufitInk : Color.ufitSecondaryText).frame(maxWidth: .infinity).contentShape(Rectangle())
    }
}
