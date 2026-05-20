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

private struct RootScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.ufitInk)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.ufitMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(Color.white)
    }
}

private struct SearchOutfitsView: View {
    let store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void

    @State private var query = ""
    @State private var selectedFilter = "All"

    private let filters = ["All", "Minimal", "Tailored", "Evening", "Layered"]

    private var filteredOutfits: [Outfit] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let selectedNeedle = selectedFilter.lowercased()

        return store.outfits.filter { outfit in
            let searchable = (
                [outfit.title, outfit.creator, outfit.description] +
                outfit.products.map(\.name) +
                outfit.pieces.map(\.name)
            )
            .joined(separator: " ")
            .lowercased()

            let matchesQuery = normalizedQuery.isEmpty || searchable.contains(normalizedQuery)
            let matchesFilter = selectedFilter == "All" || searchable.contains(selectedNeedle)
            return matchesQuery && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            RootScreenHeader(title: "Search", subtitle: "Find outfits by creator, style, occasion, or piece.")

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SearchField(query: $query)

                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(filters, id: \.self) { filter in
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Text(filter)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(selectedFilter == filter ? .white : Color.ufitInk)
                                        .padding(.horizontal, 14)
                                        .frame(height: 36)
                                        .background(
                                            selectedFilter == filter ? Color.ufitInk : Color.white,
                                            in: Capsule()
                                        )
                                        .overlay {
                                            Capsule()
                                                .stroke(Color.ufitBorder, lineWidth: selectedFilter == filter ? 0 : 1)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)

                    if filteredOutfits.isEmpty {
                        EmptySearchState()
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredOutfits) { outfit in
                                Button {
                                    onOutfitTap(outfit)
                                } label: {
                                    SavedOutfitRow(outfit: outfit)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
        .task {
            await store.loadFeedIfNeeded()
        }
    }
}

private struct SearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.ufitMuted)

            TextField("Style, creator, product", text: $query)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .frame(height: 48)
        .padding(.horizontal, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.ufitBorder, lineWidth: 1)
        }
        .padding(.horizontal, 24)
    }
}

private struct EmptySearchState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(Color.ufitMuted)
            Text("No looks found")
                .font(.system(size: 18, weight: .semibold))
            Text("Try a creator name, a style mood, or one product category.")
                .font(.system(size: 14))
                .foregroundStyle(Color.ufitMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CreateWorkspaceView: View {
    let store: MarketplaceStore
    let onCreatorTap: () -> Void
    let onBrandTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RootScreenHeader(title: "Create", subtitle: "Compose looks and manage partner workspaces.")

            ScrollView {
                VStack(spacing: 14) {
                    WorkspaceEntryCard(
                        systemImage: "sparkles",
                        title: "Creator studio",
                        subtitle: creatorSubtitle,
                        primaryMetric: creatorMetric,
                        actionTitle: "Open profile",
                        action: onCreatorTap
                    )

                    WorkspaceEntryCard(
                        systemImage: "shippingbox",
                        title: "Brand workspace",
                        subtitle: brandSubtitle,
                        primaryMetric: brandMetric,
                        actionTitle: "Open dashboard",
                        action: onBrandTap
                    )

                    WorkspaceNotice(
                        text: store.isAuthenticated
                            ? "Live workspace data is loaded through the backend API when profile identifiers are available."
                            : "Set UFIT_API_BEARER_TOKEN to enable authenticated creator, brand, saved, cart, and checkout actions."
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
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

private struct WorkspaceEntryCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let primaryMetric: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
                    .frame(width: 44, height: 44)
                    .background(Color.ufitSecondary, in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.ufitInk)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ufitMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack {
                Text(primaryMetric)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.ufitSecondary, in: Capsule())

                Spacer()

                Button(action: action) {
                    HStack(spacing: 7) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(CompactPrimaryButtonStyle())
                .frame(width: 148)
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.ufitBorder, lineWidth: 1)
        }
    }
}

private struct WorkspaceNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.ufitMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SavedOutfitsView: View {
    let store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void

    private var savedOutfits: [Outfit] {
        store.outfits.filter { store.savedOutfitIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            RootScreenHeader(title: "Saved", subtitle: "Curated looks you kept for later.")

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if savedOutfits.isEmpty {
                        EmptySavedState()
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(savedOutfits) { outfit in
                                Button {
                                    onOutfitTap(outfit)
                                } label: {
                                    SavedOutfitRow(outfit: outfit)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
        .task {
            await store.loadFeedIfNeeded()
        }
    }
}

private struct SavedOutfitRow: View {
    let outfit: Outfit

    var body: some View {
        HStack(spacing: 14) {
            FashionImage(source: outfit.imageName)
                .frame(width: 86, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(outfit.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ufitInk)
                Text(outfit.creator)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.ufitMuted)
                Text(outfit.price)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.ufitBorder, lineWidth: 1)
        )
    }
}

private struct EmptySavedState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 26))
                .foregroundStyle(Color.ufitMuted)
            Text("No saved outfits yet")
                .font(.system(size: 18, weight: .semibold))
            Text("Tap the heart on any outfit to keep it here.")
                .font(.system(size: 14))
                .foregroundStyle(Color.ufitMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    MarketplaceRootView()
}
