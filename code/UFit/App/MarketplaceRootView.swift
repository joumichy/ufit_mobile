import SwiftUI

struct MarketplaceRootView: View {
    @State private var store = MarketplaceStore.live()
    @State private var showOnboarding = !ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
    @State private var activeTab: AppTab = ProcessInfo.processInfo.arguments.contains("--start-profile") ? .profile : .feed
    @State private var activeRoute: AppRoute = ProcessInfo.processInfo.arguments.contains("--start-profile") ? .creator : .feed
    @State private var creatorProfileViewID = UUID()

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
                store: store,
                onOutfitTap: showOutfitDetail,
                onCreatorTap: showCreatorProfile
            )
        case .search:
            SearchOutfitsView(store: store, onOutfitTap: showOutfitDetail)
        case .create:
            CreateWorkspaceView(
                store: store,
                onCreatorTap: showCreatorProfile,
                onBrandTap: showBrandWorkspace
            )
        case .outfit(let outfit):
            OutfitDetailView(store: store, outfit: outfit, onBack: returnToFeed)
        case .saved:
            SavedOutfitsView(store: store, onOutfitTap: showOutfitDetail)
        case .creator:
            CreatorProfileView(store: store, onBack: returnToFeed)
                .id(creatorProfileViewID)
        case .brand:
            BrandDashboardView(store: store, onBack: returnToFeed)
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
        case .feed:
            activeRoute = .feed
        case .search:
            activeRoute = .search
        case .create:
            activeRoute = .create
        case .saved:
            activeRoute = .saved
        case .profile:
            activeRoute = .creator
            creatorProfileViewID = UUID()
        }
    }

    func showOutfitDetail(_ outfit: Outfit) {
        activeRoute = .outfit(outfit)
    }

    func showCreatorProfile() {
        activeRoute = .creator
        activeTab = .profile
        creatorProfileViewID = UUID()
    }

    func showBrandWorkspace() {
        activeRoute = .brand
    }

    func returnToFeed() {
        activeRoute = .feed
        activeTab = .feed
    }
}

private enum AppRoute {
    case feed
    case search
    case create
    case outfit(Outfit)
    case saved
    case creator
    case brand
}

private struct SearchOutfitsView: View {
    let store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void

    var body: some View {
        SearchOutfitsContentView(outfits: store.outfits, onOutfitTap: onOutfitTap)
            .task { await store.loadFeedIfNeeded() }
    }
}

private struct CreateWorkspaceView: View {
    let store: MarketplaceStore
    let onCreatorTap: () -> Void
    let onBrandTap: () -> Void

    var body: some View {
        CreateWorkspaceContentView(
            creatorSubtitle: creatorSubtitle,
            creatorMetric: creatorMetric,
            brandSubtitle: brandSubtitle,
            brandMetric: brandMetric,
            noticeText: store.isAuthenticated
                ? "Live workspace data is loaded through the backend API when profile identifiers are available."
                : "Set UFIT_API_BEARER_TOKEN to enable authenticated creator, brand, saved, cart, and checkout actions.",
            onCreatorTap: onCreatorTap,
            onBrandTap: onBrandTap
        )
        .task {
            guard store.isAuthenticated else { return }
            await store.loadCreatorWorkspace()
            if store.brandProfileID != nil {
                await store.loadBrandWorkspace()
            }
        }
    }

    private var creatorSubtitle: String {
        if let profile = store.creatorDashboard?.profile {
            return "\(profile.displayName) · \(profile.grade.label)"
        }
        return "Submit and track selected outfits."
    }

    private var creatorMetric: String {
        if let performance = store.creatorDashboard?.performance {
            return "\(performance.outfits.published) published"
        }
        return "\(store.outfits.count) looks available"
    }

    private var brandSubtitle: String {
        if let profile = store.brandDashboard?.profile {
            return "\(profile.brandName) · \(profile.memberRole)"
        }
        if store.brandProfileID == nil {
            return "Set UFIT_BRAND_PROFILE_ID to bind this app to a brand."
        }
        return "Manage products, stock, and orders."
    }

    private var brandMetric: String {
        if let performance = store.brandDashboard?.performance {
            return "\(performance.products.active) active products"
        }
        return "\(store.brandOrders.count) sample orders"
    }
}

private struct SavedOutfitsView: View {
    let store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void

    var body: some View {
        SavedOutfitsContentView(
            outfits: store.outfits.filter { store.savedOutfitIDs.contains($0.id) },
            onOutfitTap: onOutfitTap
        )
        .task { await store.loadFeedIfNeeded() }
    }
}

#Preview {
    MarketplaceRootView()
}
