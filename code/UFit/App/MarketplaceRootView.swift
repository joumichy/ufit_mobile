import SwiftUI

struct MarketplaceRootView: View {
    @State private var showOnboarding = !ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
    @State private var activeTab: AppTab = .feed
    @State private var activeRoute: AppRoute = .feed

    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView(onComplete: completeOnboarding)
            } else {
                ZStack(alignment: .bottom) {
                    routedContent
                    BottomNavBar(activeTab: activeTab, onSelect: selectTab)
                }
                .background(Color.ufitBackground)
            }
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var routedContent: some View {
        switch activeRoute {
        case .feed:
            HomeFeedView(
                onOutfitTap: showOutfitDetail,
                onCreatorTap: showCreatorProfile
            )
        case .outfit(let outfit):
            OutfitDetailView(outfit: outfit, onBack: returnToFeed)
        case .creator:
            CreatorProfileView(onBack: returnToFeed)
        case .brand:
            BrandDashboardView(onBack: returnToFeed)
        }
    }
}

private extension MarketplaceRootView {
    func completeOnboarding() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            showOnboarding = false
        }
    }

    func selectTab(_ tab: AppTab) {
        activeTab = tab

        switch tab {
        case .feed, .search, .create:
            activeRoute = .feed
        case .orders:
            activeRoute = .brand
        case .profile:
            activeRoute = .creator
        }
    }

    func showOutfitDetail(_ outfit: Outfit) {
        activeRoute = .outfit(outfit)
    }

    func showCreatorProfile() {
        activeRoute = .creator
        activeTab = .profile
    }

    func returnToFeed() {
        activeRoute = .feed
        activeTab = .feed
    }
}

private enum AppRoute {
    case feed
    case outfit(Outfit)
    case creator
    case brand
}

#Preview {
    MarketplaceRootView()
}
