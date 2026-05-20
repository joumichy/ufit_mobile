import SwiftUI

struct BottomNavBar: View {
    let activeTab: AppTab
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    BottomNavItem(tab: tab, isActive: activeTab == tab)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.ufitBorder)
                .frame(height: 1)
        }
    }
}

private struct BottomNavItem: View {
    let tab: AppTab
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isActive ? tab.activeSystemImage : tab.systemImage)
                .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                .frame(height: 24)
            Text(tab.title)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
        }
        .foregroundStyle(isActive ? Color.ufitInk : Color.ufitMuted)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
