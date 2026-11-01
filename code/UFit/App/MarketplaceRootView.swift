import SwiftUI
import StripePaymentSheet

struct MarketplaceRootView: View {
    @State private var session: UFitSessionStore
    @State private var store: MarketplaceStore
    @State private var cart: UFitCartStore
    @State private var orders: UFitOrdersStore
    @State private var workspaces: UFitWorkspacesStore
    @State private var applications: UFitApplicationsStore
    @State private var adminApplications: UFitApplicationQueueStore
    @State private var routeHistory: [AppRoute] = []
    @State private var showAuthentication = false

    init() {
        let session = UFitSessionStore()
        _session = State(initialValue: session)
        _store = State(initialValue: MarketplaceStore.live(client: session.api, session: session))
        _cart = State(initialValue: UFitCartStore(client: session.api, session: session))
        _orders = State(initialValue: UFitOrdersStore(client: session.api, session: session))
        _workspaces = State(initialValue: UFitWorkspacesStore(client: session.api, session: session))
        _applications = State(initialValue: UFitApplicationsStore(client: session.api, session: session))
        _adminApplications = State(initialValue: UFitApplicationQueueStore(client: session.api, session: session))
    }
    @State private var showOnboarding = !ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
    @State private var activeTab: AppTab = ProcessInfo.processInfo.arguments.contains("--start-profile") ? .profile : .feed
    @State private var activeRoute: AppRoute = ProcessInfo.processInfo.arguments.contains("--start-profile") ? .account : .feed

    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView(onComplete: completeOnboarding)
            } else {
                ZStack(alignment: .bottom) {
                    routedContent
                    if !hidesTabBar { BottomNavBar(activeTab: activeTab, onSelect: selectTab) }
                }
                .background(Color.ufitBackground)
            }
        }
        .preferredColorScheme(.light)
        .task { session.start() }
        .onOpenURL { url in
            if case .connect(let connect) = activeRoute { Task { await connect.handleCallback(url) } }
            if !StripeAPI.handleURLCallback(with: url), url.host == "auth" { Task { await session.handle(url) } }
        }
        .onChange(of: session.user?.id) { previousUserID, userID in
            store.clearAccountData()
            cart.reset()
            orders.reset()
            workspaces.reset()
            applications.reset()
            adminApplications.reset()
            if previousUserID != nil { returnToFeed() }
            if userID != nil { Task { await store.loadSavedOutfits() } }
        }
        .onChange(of: session.needsNewPassword) { _, needed in
            if needed { showAuthentication = true }
        }
        .onChange(of: showAuthentication) { _, showing in
            if !showing, case .publicProfile(let profile) = activeRoute { Task { await profile.loadFollow(refreshProfile: true) } }
        }
        .sheet(isPresented: $showAuthentication) {
            UFitAuthenticationHost(session: session, onBrowse: { showAuthentication = false })
        }
    }

    @ViewBuilder
    private var routedContent: some View {
        switch activeRoute {
        case .feed:
            HomeFeedView(
                store: store,
                onOutfitTap: showOutfitDetail,
                onAuthorTap: { author in showPublicProfile(.init(id: author.id, kind: author.kind)) },
                onItemTap: showOutfitItem,
                onSignIn: { showAuthentication = true }
            )
        case .search:
            SearchOutfitsView(store: store, onOutfitTap: showOutfitDetail)
        case .create:
            UFitWorkspacesHost(store: workspaces, canAdminister: session.user?.canAdminister == true,
                onOpen: showManagedProfile, onApplications: showApplications, onPayments: showPayments,
                onAdminApplications: showAdminApplications, onCatalog: showBrandCatalog, onCommercePolicy: showBrandCommercePolicy, onOrders: showBrandOrders, onReturns: showBrandReturns, onAdminReturns: showAdminReturns, onAdminProducts: showAdminProducts,
                onOutfits: showManagedOutfits, onAdminOutfits: showAdminOutfits,
                onPublicProfile: { space in showPublicProfile(.init(id: space.profileID, kind: space.isCreator ? .creator : .brand)) }, onDashboard: showWorkspaceDashboard)
        case .workspaceDashboard(let dashboard):
            UFitWorkspaceDashboardHost(store: dashboard, onBack: goBack, onCommissions: showWorkspaceCommissions)
        case .workspaceCommissions(let commissions):
            UFitWorkspaceCommissionsHost(store: commissions, onBack: goBack)
        case .managedOutfits(let outfits):
            UFitManagedOutfitsHost(store: outfits, onBack: goBack, onOpen: showManagedOutfit, onCreate: showOutfitForm)
        case .managedOutfit(let outfit):
            UFitManagedOutfitHost(store: outfit, onBack: goBack, onEdit: showOutfitEditor)
        case .outfitForm(let form):
            UFitOutfitFormHost(store: form, onBack: goBack, onSaved: { finishOutfitForm(form, outfit: $0) })
        case .returns(let list):
            UFitReturnsHost(store: list, onBack: goBack, onOpen: showReturnDetail, onCreate: showReturnCreation)
        case .returnDetail(let detail):
            UFitReturnDetailHost(store: detail, onBack: goBack)
        case .returnCreation(let form, let list):
            UFitReturnCreationHost(store: form, onClose: goBack, onCreated: { result in
                list.receive(result.summary); openReturnFromCreation(result.id)
            }, onOpenExisting: openReturnFromCreation)
        case .brandOrders(let list):
            UFitBrandOrdersHost(store: list, onBack: goBack, onOpen: showBrandOrder)
        case .brandOrder(let order):
            UFitBrandOrderHost(store: order, onBack: goBack)
        case .brandCommercePolicy(let policy):
            UFitBrandCommercePolicyHost(store: policy, onBack: goBack)
        case .catalog(let catalog):
            UFitCatalogHost(store: catalog, onBack: goBack, onOpen: showCatalogProduct, onCreate: showCatalogForm)
        case .catalogProduct(let product):
            UFitCatalogProductHost(store: product, onBack: goBack, onEdit: showProductEditor, onStock: showCatalogStock)
        case .catalogForm(let form):
            UFitCatalogFormHost(store: form, onBack: goBack, onSaved: { finishCatalogForm(form, product: $0) })
        case .catalogStock(let stock):
            UFitCatalogStockHost(store: stock, onBack: goBack)
        case .managedProfile(let profile):
            UFitManagedProfileHost(store: profile, onBack: goBack)
        case .outfit(let outfit, let shopping, let itemID):
            OutfitDetailView(outfit: outfit, shopping: shopping, session: session, cart: cart,
                onAuthor: { author in showPublicProfile(.init(id: author.id, kind: author.kind)) },
                onBrand: { id in showPublicProfile(.init(id: id, kind: .brand)) }, onBack: goBack, onCart: showCart, onSignIn: { showAuthentication = true }, focusedItemID: itemID)
        case .cart:
            UFitCartHost(store: cart, onBack: goBack, onCheckout: showCheckout)
        case .checkout(let checkout):
            UFitCheckoutHost(store: checkout, onBack: goBack, onFinish: {showPurchasedOrder(checkout)})
        case .saved:
            SavedOutfitsView(store: store, onOutfitTap: showOutfitDetail)
        case .account:
            UFitAccountHost(session: session, onSignedOut: returnToFeed, onOrders: showOrders, onPayments: showPayments, onApplications: showApplications, onAdminApplications: showAdminApplications)
        case .applications:
            UFitApplicationsHost(store: applications, onBack: goBack, onApply: showApplicationForm, onPayments: showPayments)
        case .applicationForm(let form):
            UFitApplicationFormHost(store: form, onBack: goBack, onSubmitted: goBack)
        case .adminApplications:
            UFitApplicationQueueHost(store: adminApplications, onBack: goBack, onOpen: showAdminApplication)
        case .adminApplication(let review):
            UFitApplicationReviewHost(store: review, onBack: goBack)
        case .connect(let connect):
            UFitConnectHost(store: connect, onBack: goBack)
        case .orders:
            UFitOrdersHost(store: orders, onBack: goBack, onSelect: showOrder)
        case .order(let order):
            UFitOrderDetailHost(store: order, onBack: goBack, onReturns: showCustomerReturns)
        case .publicProfile(let profile):
            UFitPublicProfileHost(store: profile, session: session, onBack: goBack, onSignIn: { showAuthentication = true }, onOpen: showOutfitDetail)
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
        if (tab == .profile || tab == .saved || tab == .create) && session.user == nil {
            showAuthentication = true
            return
        }
        routeHistory = []
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
            activeRoute = .account
        }
    }

    func showOutfitItem(_ outfit: Outfit, itemID: String) {
        guard outfit.products.contains(where: { $0.id == itemID }) else { return }
        routeHistory.append(activeRoute)
        activeRoute = .outfit(outfit, UFitOutfitShoppingStore(client: session.api), itemID)
    }

    func showOutfitDetail(_ outfit: Outfit) {
        routeHistory.append(activeRoute)
        activeRoute = .outfit(outfit, UFitOutfitShoppingStore(client: session.api), nil)
    }

    func showPublicProfile(_ reference: UFitPublicProfileReference) {
        guard UUID(uuidString: reference.id) != nil else { return }
        routeHistory.append(activeRoute)
        activeRoute = .publicProfile(UFitPublicProfileStore(reference: reference, client: session.api, session: session))
    }

    func showWorkspaceDashboard(_ space: UFitWorkspaceReference) {
        guard case .create = activeRoute, workspaces.spaces.contains(space), space.status != .suspended, let userID = session.user?.id else { return }
        routeHistory.append(activeRoute)
        activeRoute = .workspaceDashboard(UFitWorkspaceDashboardStore(workspace: space, session: session, userID: userID))
    }
    func showWorkspaceCommissions() {
        guard case .workspaceDashboard(let dashboard) = activeRoute, dashboard.isCurrentAccount,
            dashboard.workspace.isCreator, let document = dashboard.document, let userID = session.user?.id else { return }
        routeHistory.append(activeRoute)
        activeRoute = .workspaceCommissions(UFitWorkspaceCommissionsStore(name: document.name, session: session, userID: userID))
    }

    func showManagedProfile(_ space: UFitWorkspaceReference) {
        guard let userID = session.user?.id else { return }
        Task {
            guard let profile = await workspaces.open(space), session.user?.id == userID,
                  case .create = activeRoute else { return }
            routeHistory.append(activeRoute)
            activeRoute = .managedProfile(profile)
        }
    }

    var hidesTabBar: Bool {
        switch activeRoute { case .workspaceDashboard, .workspaceCommissions, .checkout, .applicationForm, .adminApplication, .managedProfile, .catalogProduct, .catalogForm, .catalogStock, .managedOutfit, .outfitForm, .brandCommercePolicy, .brandOrders, .brandOrder, .returns, .returnDetail, .returnCreation: true; default: false }
    }

    func showCustomerReturns() {
        guard case .order(let detail) = activeRoute, !detail.isBusy, let order = detail.order, session.user != nil else { return }
        do {
            let list = try UFitReturnsStore(scope: .customer(orderID: order.id), context: order.orderNumber, session: session)
            routeHistory.append(activeRoute); activeRoute = .returns(list)
        } catch { detail.message = error.localizedDescription }
    }
    func showBrandReturns(_ space: UFitWorkspaceReference) {
        guard case .create = activeRoute, session.user != nil, workspaces.spaces.contains(space), !space.isCreator,
              space.status == .active || space.status == .paused else { return }
        do {
            let list = try UFitReturnsStore(scope: .brand(brandID: space.profileID), context: space.name, session: session)
            routeHistory.append(activeRoute); activeRoute = .returns(list)
        } catch { workspaces.reportOpeningFailure(error, space: space) }
    }
    func showAdminReturns() {
        guard case .create = activeRoute, session.user?.canAdminister == true else { return }
        do {
            let list = try UFitReturnsStore(scope: .administrator, context: String(localized: "Retours et arbitrages"), session: session)
            routeHistory.append(activeRoute); activeRoute = .returns(list)
        } catch { workspaces.reportOpeningFailure(error) }
    }
    func showReturnDetail(_ id: String) {
        guard case .returns(let list) = activeRoute, list.isCurrentAccount else { return }
        do {
            let detail = try UFitReturnDetailStore(id: id, list: list)
            routeHistory.append(activeRoute); activeRoute = .returnDetail(detail)
        } catch { list.reportOpeningFailure(error) }
    }
    func showReturnCreation() {
        guard case .returns(let list) = activeRoute, list.isCurrentAccount, case .customer(let orderID) = list.scope else { return }
        do {
            let form = try UFitReturnCreationStore(orderID: orderID, orderNumber: list.context, session: session)
            routeHistory.append(activeRoute); activeRoute = .returnCreation(form, list)
        } catch { list.reportOpeningFailure(error) }
    }
    func openReturnFromCreation(_ id: String) {
        guard case .returnCreation(let form, let list) = activeRoute, form.isCurrentAccount, list.isCurrentAccount,
              id == form.created?.id || id == form.options?.openReturnId else { return }
        do {
            let detail = try UFitReturnDetailStore(id: id, list: list)
            if let result = form.created, result.id == id { detail.receive(result) }
            activeRoute = .returnDetail(detail)
        } catch { list.reportOpeningFailure(error) }
    }
    func showBrandOrders(_ space: UFitWorkspaceReference) {
        guard case .create = activeRoute, session.user != nil, workspaces.spaces.contains(space), !space.isCreator, space.status == .active || space.status == .paused else { return }
        do {
            let list = try UFitBrandOrdersStore(space: space, session: session)
            routeHistory.append(activeRoute); activeRoute = .brandOrders(list)
        } catch { workspaces.reportOpeningFailure(error, space: space) }
    }
    func showBrandOrder(_ id: String) {
        guard case .brandOrders(let list) = activeRoute, list.isCurrentAccount else { return }
        do {
            let order = try UFitBrandOrderStore(id: id, list: list)
            routeHistory.append(activeRoute); activeRoute = .brandOrder(order)
        } catch { list.reportOpeningFailure(error) }
    }

    func showBrandCommercePolicy(_ space: UFitWorkspaceReference) {
        guard case .create = activeRoute, session.user != nil, workspaces.spaces.contains(space), !space.isCreator, space.status == .active || space.status == .paused else { return }
        do {
            let policy = try UFitBrandCommercePolicyStore(space: space, session: session)
            routeHistory.append(activeRoute); activeRoute = .brandCommercePolicy(policy)
        } catch { workspaces.reportOpeningFailure(error, space: space) }
    }

    func showManagedOutfits(_ space: UFitWorkspaceReference) {
        guard session.user != nil, space.status == .active || space.status == .paused else { return }
        routeHistory.append(activeRoute)
        activeRoute = .managedOutfits(UFitManagedOutfitsStore(scope: .init(workspace: space), title: OutfitCopy.title,
            subtitle: space.name, access: .author, client: session.api, session: session))
    }
    func showAdminOutfits() {
        guard session.user?.canAdminister == true else { return }
        routeHistory.append(activeRoute)
        activeRoute = .managedOutfits(UFitManagedOutfitsStore(scope: nil, title: OutfitCopy.moderation,
            subtitle: OutfitCopy.allAuthors, access: .moderator, client: session.api, session: session))
    }
    func showManagedOutfit(_ outfit: UFitManagedOutfitStore) {
        guard outfit.collection.isCurrentAccount, case .managedOutfits(let current) = activeRoute, current === outfit.collection else { return }
        routeHistory.append(activeRoute); activeRoute = .managedOutfit(outfit)
    }
    func showOutfitForm(_ outfits: UFitManagedOutfitsStore) {
        guard outfits.isCurrentAccount, case .managedOutfits(let current) = activeRoute, current === outfits else { return }
        do { let form = try UFitOutfitFormStore(collection: outfits, original: nil); routeHistory.append(activeRoute); activeRoute = .outfitForm(form) }
        catch { outfits.report(error) }
    }
    func showOutfitEditor(_ outfit: UFitManagedOutfitStore) {
        guard outfit.collection.isCurrentAccount, case .managedOutfit(let current) = activeRoute, current === outfit else { return }
        do { let form = try UFitOutfitFormStore(collection: outfit.collection, original: outfit.document); routeHistory.append(activeRoute); activeRoute = .outfitForm(form) }
        catch { outfit.report(error) }
    }
    func finishOutfitForm(_ form: UFitOutfitFormStore, outfit: UFitManagedOutfit) {
        guard form.collection.isCurrentAccount, case .outfitForm(let current) = activeRoute, current === form else { return }
        if form.isNew {
            form.cancelPhotoUploads(); activeRoute = .managedOutfit(UFitManagedOutfitStore(document: outfit, collection: form.collection))
        } else if let prior = routeHistory.last, case .managedOutfit(let previous) = prior {
            do { try previous.receive(outfit); goBack() }
            catch { previous.report(error) }
        }
    }
    private enum OutfitCopy {
        static let title = String(localized: "Mes tenues"); static let moderation = String(localized: "Modération des tenues")
        static let allAuthors = String(localized: "Créateurs et marques")
    }

    func showBrandCatalog(_ space: UFitWorkspaceReference) {
        guard case .brand = space, space.status != .suspended, session.user != nil else { return }
        routeHistory.append(activeRoute)
        activeRoute = .catalog(UFitCatalogStore(brandID: space.profileID, title: CatalogCopy.title, subtitle: space.name, access: .member, client: session.api, session: session))
    }
    func showAdminProducts() {
        guard session.user?.canAdminister == true else { return }
        routeHistory.append(activeRoute)
        activeRoute = .catalog(UFitCatalogStore(brandID: nil, title: CatalogCopy.moderation, subtitle: CatalogCopy.allBrands, access: .moderator, client: session.api, session: session))
    }
    func showCatalogProduct(_ product: UFitCatalogProductStore) {
        guard product.catalog.isCurrentAccount, case .catalog(let current) = activeRoute, current === product.catalog else { return }
        routeHistory.append(activeRoute); activeRoute = .catalogProduct(product)
    }
    func showCatalogForm(_ catalog: UFitCatalogStore) {
        guard catalog.isCurrentAccount, case .catalog(let current) = activeRoute, current === catalog else { return }
        do { let form = try UFitCatalogFormStore(catalog: catalog, original: nil); routeHistory.append(activeRoute); activeRoute = .catalogForm(form) }
        catch { catalog.report(error) }
    }
    func showProductEditor(_ product: UFitCatalogProductStore) {
        guard product.catalog.isCurrentAccount else { return }
        do { let form = try UFitCatalogFormStore(catalog: product.catalog, original: product.document); routeHistory.append(activeRoute); activeRoute = .catalogForm(form) }
        catch { product.report(error) }
    }
    func showCatalogStock(_ product: UFitCatalogProductStore, variantID: String) {
        guard product.catalog.isCurrentAccount, product.catalog.access == .member, product.document.product.status != .archived,
              let variant = product.document.variants.first(where: { $0.id == variantID && $0.status != .archived }) else { return }
        routeHistory.append(activeRoute); activeRoute = .catalogStock(UFitCatalogStockStore(product: product, variant: variant))
    }
    func finishCatalogForm(_ form: UFitCatalogFormStore, product: UFitManagedProduct) {
        guard form.catalog.isCurrentAccount, case .catalogForm(let current) = activeRoute, current === form else { return }
        if form.isNew {
            form.cancelPhotoUploads(); activeRoute = .catalogProduct(UFitCatalogProductStore(document: product, catalog: form.catalog))
        } else if let prior = routeHistory.last, case .catalogProduct(let previous) = prior {
            do { try previous.receive(product); goBack() }
            catch { previous.report(error) }
        }
    }
    private enum CatalogCopy {
        static let title = String(localized: "Catalogue"); static let moderation = String(localized: "Modération produits"); static let allBrands = String(localized: "Toutes les marques")
    }

    func showApplications() {
        guard session.user != nil else { showAuthentication = true; return }
        routeHistory.append(activeRoute)
        activeRoute = .applications
    }
    func showApplicationForm(_ kind: UFitApplicationKind, _ correcting: UFitApplicationDocument?) {
        routeHistory.append(activeRoute)
        activeRoute = .applicationForm(UFitApplicationFormStore(kind: kind, correcting: correcting, client: session.api, session: session))
    }
    func showAdminApplications() {
        guard session.user?.canAdminister == true else { return }
        routeHistory.append(activeRoute)
        activeRoute = .adminApplications
    }
    func showAdminApplication(_ item: UFitApplicationQueueItem) {
        guard session.user?.canAdminister == true else { return }
        routeHistory.append(activeRoute)
        activeRoute = .adminApplication(UFitApplicationReviewStore(kind: item.type, id: item.id, client: session.api, session: session, queue: adminApplications))
    }

    func showCheckout() {
        guard session.user != nil else { showAuthentication = true; return }
        routeHistory.append(activeRoute)
        activeRoute = .checkout(UFitCheckoutStore(client: session.api, cart: cart, name: session.user?.displayName))
    }

    func showPayments() {
        guard session.user != nil else { showAuthentication = true; return }
        routeHistory.append(activeRoute)
        activeRoute = .connect(UFitConnectStore(client: session.api, session: session))
    }
    func showOrders() {
        guard session.user != nil else {showAuthentication = true; return}
        routeHistory.append(activeRoute)
        activeRoute = .orders
    }
    func showOrder(_ id: String) {
        routeHistory.append(activeRoute)
        activeRoute = .order(UFitOrderDetailStore(id: id, client: session.api, session: session, orders: orders))
    }
    func showPurchasedOrder(_ checkout: UFitCheckoutStore) {
        guard let purchased = checkout.order else {returnToFeed(); return}
        orders.receive(purchased)
        activeTab = .profile
        routeHistory = [.account, .orders]
        activeRoute = .order(UFitOrderDetailStore(id: purchased.id, client: session.api, session: session, orders: orders))
    }

    func showCart() {
        guard session.user != nil else { showAuthentication = true; return }
        routeHistory.append(activeRoute)
        activeRoute = .cart
    }

    func goBack() {
        if case .catalogForm(let form) = activeRoute { form.cancelPhotoUploads() }
        if case .outfitForm(let form) = activeRoute { form.cancelPhotoUploads() }
        activeRoute = routeHistory.popLast() ?? .feed
    }

    func returnToFeed() {
        if case .catalogForm(let form) = activeRoute { form.cancelPhotoUploads() }
        if case .outfitForm(let form) = activeRoute { form.cancelPhotoUploads() }
        routeHistory = []
        activeRoute = .feed
        activeTab = .feed
    }
}

private enum AppRoute {
    case feed
    case search
    case create
    case workspaceDashboard(UFitWorkspaceDashboardStore)
    case workspaceCommissions(UFitWorkspaceCommissionsStore)
    case managedProfile(UFitManagedProfileStore)
    case managedOutfits(UFitManagedOutfitsStore)
    case managedOutfit(UFitManagedOutfitStore)
    case outfitForm(UFitOutfitFormStore)
    case brandCommercePolicy(UFitBrandCommercePolicyStore)
    case returns(UFitReturnsStore)
    case returnDetail(UFitReturnDetailStore)
    case returnCreation(UFitReturnCreationStore, UFitReturnsStore)
    case brandOrders(UFitBrandOrdersStore)
    case brandOrder(UFitBrandOrderStore)
    case catalog(UFitCatalogStore)
    case catalogProduct(UFitCatalogProductStore)
    case catalogForm(UFitCatalogFormStore)
    case catalogStock(UFitCatalogStockStore)
    case outfit(Outfit, UFitOutfitShoppingStore, String?)
    case cart
    case checkout(UFitCheckoutStore)
    case saved
    case account
    case applications
    case applicationForm(UFitApplicationFormStore)
    case adminApplications
    case adminApplication(UFitApplicationReviewStore)
    case connect(UFitConnectStore)
    case orders
    case order(UFitOrderDetailStore)
    case publicProfile(UFitPublicProfileStore)
}

private struct SearchOutfitsView: View {
    let store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void
    var body: some View {
        SearchOutfitsContentView(outfits: store.outfits, onOutfitTap: onOutfitTap)
            .task { await store.loadFeedIfNeeded() }
    }
}

private struct SavedOutfitsView: View {
    let store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void
    var body: some View {
        SavedOutfitsContentView(outfits: store.savedOutfits, onOutfitTap: onOutfitTap)
            .task { await store.loadSavedOutfits() }
    }
}

#Preview {
    MarketplaceRootView()
}
