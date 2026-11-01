import SwiftUI

struct BottomNavBar: View {
    let activeTab: AppTab
    var experience: UFitExperienceKind = .customer
    var cartCount: Int = .zero
    let onSelect: (AppTab) -> Void
    private enum Layout {
        static let horizontal: CGFloat = 12; static let top: CGFloat = 10; static let bottom: CGFloat = 10
        static let border: CGFloat = 1; static let touch: CGFloat = 48
    }
    var body: some View {
        HStack(spacing: .zero) {
            ForEach(experience.tabs) { tab in
                Button { onSelect(tab) } label: {
                    BottomNavItem(tab: tab, isActive: activeTab == tab, count: tab == .cart ? cartCount : .zero)
                }.buttonStyle(.plain).frame(maxWidth: .infinity, minHeight: Layout.touch)
                    .accessibilityLabel(tab.title)
                    .accessibilityRemoveTraits(activeTab == tab ? [] : .isSelected)
                    .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
            }
        }.padding(.horizontal, Layout.horizontal).padding(.top, Layout.top).padding(.bottom, Layout.bottom)
            .background(Color.white.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: Layout.border) }
    }
}
struct BottomNavItem: View {
    let tab: AppTab
    let isActive: Bool
    var count: Int = .zero
    private enum Layout {
        static let gap: CGFloat = 4; static let icon: CGFloat = 22; static let iconHeight: CGFloat = 24
        static let label: CGFloat = 11; static let badge: CGFloat = 16; static let offset: CGFloat = 12
    }
    var body: some View {
        VStack(spacing: Layout.gap) {
            Image(systemName: isActive ? tab.activeSystemImage : tab.systemImage)
                .font(.system(size: Layout.icon, weight: isActive ? .semibold : .regular)).frame(height: Layout.iconHeight)
                .overlay(alignment: .topTrailing) {
                    if count > .zero {
                        Text(count, format: .number).font(.caption2.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, Layout.gap).frame(minWidth: Layout.badge, minHeight: Layout.badge)
                            .background(Color.ufitInk, in: Capsule()).offset(x: Layout.offset, y: -Layout.gap)
                    }
                }
            Text(tab.title).font(.system(size: Layout.label, weight: isActive ? .semibold : .regular)).lineLimit(2)
        }.foregroundStyle(isActive ? Color.ufitInk : Color.ufitMuted).frame(maxWidth: .infinity).contentShape(Rectangle())
    }
}
