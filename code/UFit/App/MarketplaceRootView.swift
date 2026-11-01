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
    @State private var experience: UFitExperienceStore
    @State private var adminActivity: UFitAdminActivityStore
    @State private var professionalDashboard: UFitWorkspaceDashboardStore?
    @State private var appliedExperience = UFitExperienceSelection.customer
    @State private var showExperienceChooser = false
    @State private var preserveCustomerContextOnSignIn = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var routeHistory: [AppRoute] = []
    @State private var showAuthentication = false

    init() {
        let session = UFitSessionStore()
        _session = State(initialValue: session)
        _store = State(initialValue: MarketplaceStore.live(client: session.api, session: session))
        _cart = State(initialValue: UFitCartStore(client: session.api, session: session))
        _orders = State(initialValue: UFitOrdersStore(client: session.api, session: session))
        let workspaces = UFitWorkspacesStore(client: session.api, session: session)
        _workspaces = State(initialValue: workspaces)
        _experience = State(initialValue: UFitExperienceStore(session: session, workspaces: workspaces))
        _adminActivity = State(initialValue: UFitAdminActivityStore(session: session))
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
                    routedContent.environment(\.ufitPrimarySection, routeHistory.isEmpty)
                    if !hidesTabBar { BottomNavBar(activeTab: activeTab, experience: experience.kind, cartCount: cart.count, onSelect: selectTab) }
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
            adminApplications.reset(); adminActivity.reset(); professionalDashboard = nil; experience.reset(); appliedExperience = .customer
            if previousUserID != nil { returnToFeed() }
            if userID != nil {
                if preserveCustomerContextOnSignIn { experience.choose(.customer) }
                preserveCustomerContextOnSignIn = false
                Task { await experience.load(); await store.loadSavedOutfits(); await cart.load() }
            }
        }
        .onChange(of: experience.selected) { _, _ in applyExperienceNavigation() }
        .onChange(of: experience.asksForChoice) { _, requested in
            if requested && !showAuthentication { showExperienceChooser = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && session.user != nil { Task { await experience.load() } }
        }
        .onChange(of: session.needsNewPassword) { _, needed in
            if needed { showAuthentication = true }
        }
        .onChange(of: showAuthentication) { _, showing in
            if !showing {
                if session.user == nil { preserveCustomerContextOnSignIn = false }
                if experience.asksForChoice { showExperienceChooser = true }
                if case .publicProfile(let profile) = activeRoute { Task { await profile.loadFollow(refreshProfile: true) } }
            }
        }
        .sheet(isPresented: $showAuthentication) {
            UFitAuthenticationHost(session: session, onBrowse: { showAuthentication = false })
        }
        .sheet(isPresented: $showExperienceChooser, onDismiss: experience.dismissChoiceRequest) { experienceChooser }
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
                onSignIn: { requestSignIn(keepCustomerContext: true) }
            )
        case .search:
            SearchOutfitsView(store: store, onOutfitTap: showOutfitDetail)
        case .professionalHome:
            professionalHome
        case .professionalProfile:
            if let space = experience.workspace {
                UFitProfessionalProfileContent(workspace: space, isOpening: workspaces.busyIDs.contains(space.id), message: workspaces.message,
                    onAction: { performProfileAction($0, space: space) }, onChooseExperience: showExperiencePicker)
            } else { experienceChooser }
        case .administratorHome:
            UFitAdminActivityHost(store: adminActivity, onChooseExperience: showExperiencePicker, onApplications: showAdminApplications,
                onProducts: showAdminProducts, onOutfits: showAdminOutfits, onReturns: showAdminReturns)
        case .workspaceDashboard(let dashboard):
            UFitWorkspaceDashboardHost(store: dashboard, title: dashboard.workspace.isCreator ? AppTab.creatorEarnings.title : ExperienceCopy.sales, onBack: goBack, onCommissions: showWorkspaceCommissions)
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
                onBrand: { id in showPublicProfile(.init(id: id, kind: .brand)) }, onBack: goBack, onCart: showCart, onSignIn: { requestSignIn(keepCustomerContext: true) }, focusedItemID: itemID)
        case .cart:
            UFitCartHost(store: cart, onBack: goBack, onCheckout: showCheckout)
        case .checkout(let checkout):
            UFitCheckoutHost(store: checkout, onBack: goBack, onFinish: {showPurchasedOrder(checkout)})
        case .saved:
            SavedOutfitsView(store: store, onOutfitTap: showOutfitDetail)
        case .account:
            UFitAccountHost(session: session, onSignedOut: returnToFeed,
                onOrders: experience.kind == .customer ? showOrders : nil,
                onApplications: experience.kind == .administrator ? nil : showApplications,
                onChooseExperience: experience.canChooseAnotherExperience ? showExperiencePicker : nil,
                onBack: routeHistory.isEmpty ? nil : goBack)
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
            UFitPublicProfileHost(store: profile, session: session, onBack: goBack, onSignIn: { requestSignIn(keepCustomerContext: true) }, onOpen: showOutfitDetail)
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
        guard experience.kind.tabs.contains(tab) else { return }
        if (tab == .profile || tab == .saved || tab == .cart) && session.user == nil {
            requestSignIn(keepCustomerContext: tab != .profile); return
        }
        cancelCurrentForm(); workspaces.cancelOpening(); routeHistory = []; activeTab = tab
        switch tab {
        case .feed: activeRoute = .feed
        case .search: activeRoute = .search
        case .saved: activeRoute = .saved
        case .cart: activeRoute = .cart
        case .profile: activeRoute = .account
        case .creatorStudio, .brandActivity: activeRoute = .professionalHome
        case .creatorProfile, .brandProfile: activeRoute = .professionalProfile
        case .creatorOutfits, .brandPublications:
            if let space = experience.workspace { activeRoute = .managedOutfits(outfitCollection(space)) }
        case .creatorEarnings:
            if let dashboard = professionalDashboard { activeRoute = .workspaceDashboard(dashboard) }
        case .brandCatalog:
            if let space = experience.workspace { activeRoute = .catalog(catalogCollection(space)) }
        case .brandOrders:
            if let space = experience.workspace {
                do { activeRoute = .brandOrders(try UFitBrandOrdersStore(space: space, session: session)) }
                catch { workspaces.reportOpeningFailure(error, space: space); activeTab = .brandProfile; activeRoute = .professionalProfile }
            }
        case .adminHome: activeRoute = .administratorHome
        case .adminApplications: activeRoute = .adminApplications
        case .adminProducts:
            activeRoute = .catalog(UFitCatalogStore(brandID: nil, title: CatalogCopy.moderation, subtitle: CatalogCopy.allBrands, access: .moderator, client: session.api, session: session))
        case .adminOutfits:
            activeRoute = .managedOutfits(UFitManagedOutfitsStore(scope: nil, title: OutfitCopy.moderation, subtitle: OutfitCopy.allAuthors, access: .moderator, client: session.api, session: session))
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
        guard experience.canUse(space), let userID = session.user?.id else { return }
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
                  experience.canUse(space), case .professionalProfile = activeRoute else { return }
            routeHistory.append(activeRoute)
            activeRoute = .managedProfile(profile)
        }
    }

    var hidesTabBar: Bool { !routeHistory.isEmpty }

    func showCustomerReturns() {
        guard case .order(let detail) = activeRoute, !detail.isBusy, let order = detail.order, session.user != nil else { return }
        do {
            let list = try UFitReturnsStore(scope: .customer(orderID: order.id), context: order.orderNumber, session: session)
            routeHistory.append(activeRoute); activeRoute = .returns(list)
        } catch { detail.message = error.localizedDescription }
    }
    func showBrandReturns(_ space: UFitWorkspaceReference) {
        guard experience.canUse(space), !space.isCreator,
              space.status == .active || space.status == .paused else { return }
        do {
            let list = try UFitReturnsStore(scope: .brand(brandID: space.profileID), context: space.name, session: session)
            routeHistory.append(activeRoute); activeRoute = .returns(list)
        } catch { workspaces.reportOpeningFailure(error, space: space) }
    }
    func showAdminReturns() {
        guard experience.kind == .administrator, session.user?.canAdminister == true else { return }
        do {
            let list = try UFitReturnsStore(scope: .administrator, context: ExperienceCopy.returns, session: session)
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
    func showBrandOrder(_ id: String) {
        guard case .brandOrders(let list) = activeRoute, list.isCurrentAccount else { return }
        do {
            let order = try UFitBrandOrderStore(id: id, list: list)
            routeHistory.append(activeRoute); activeRoute = .brandOrder(order)
        } catch { list.reportOpeningFailure(error) }
    }

    func showBrandCommercePolicy(_ space: UFitWorkspaceReference) {
        guard experience.canUse(space), !space.isCreator, space.status == .active || space.status == .paused else { return }
        do {
            let policy = try UFitBrandCommercePolicyStore(space: space, session: session)
            routeHistory.append(activeRoute); activeRoute = .brandCommercePolicy(policy)
        } catch { workspaces.reportOpeningFailure(error, space: space) }
    }

    func showAdminOutfits() {
        guard experience.kind == .administrator, session.user?.canAdminister == true else { return }
        selectTab(.adminOutfits)
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

    func showAdminProducts() {
        guard experience.kind == .administrator, session.user?.canAdminister == true else { return }
        selectTab(.adminProducts)
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
        guard session.user != nil else { requestSignIn(keepCustomerContext: true); return }
        routeHistory.append(activeRoute)
        activeRoute = .applications
    }
    func showApplicationForm(_ kind: UFitApplicationKind, _ correcting: UFitApplicationDocument?) {
        routeHistory.append(activeRoute)
        activeRoute = .applicationForm(UFitApplicationFormStore(kind: kind, correcting: correcting, client: session.api, session: session))
    }
    func showAdminApplications() {
        guard experience.kind == .administrator, session.user?.canAdminister == true else { return }
        selectTab(.adminApplications)
    }
    func showAdminApplication(_ item: UFitApplicationQueueItem) {
        guard session.user?.canAdminister == true else { return }
        routeHistory.append(activeRoute)
        activeRoute = .adminApplication(UFitApplicationReviewStore(kind: item.type, id: item.id, client: session.api, session: session, queue: adminApplications))
    }

    func showCheckout() {
        guard session.user != nil else { requestSignIn(keepCustomerContext: true); return }
        routeHistory.append(activeRoute)
        activeRoute = .checkout(UFitCheckoutStore(client: session.api, cart: cart, name: session.user?.displayName))
    }

    func showPayments() {
        guard session.user != nil else { requestSignIn(keepCustomerContext: true); return }
        routeHistory.append(activeRoute)
        activeRoute = .connect(UFitConnectStore(client: session.api, session: session))
    }
    func showOrders() {
        guard session.user != nil else { requestSignIn(keepCustomerContext: true); return }
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
        guard session.user != nil else { requestSignIn(keepCustomerContext: true); return }
        if experience.kind != .customer {
            experience.choose(.customer); applyExperienceNavigation(); selectTab(.cart)
        } else { routeHistory.append(activeRoute); activeRoute = .cart }
    }

    func goBack() {
        cancelCurrentForm()
        if let previous = routeHistory.popLast() { activeRoute = previous }
        else { selectTab(experience.kind.homeTab) }
    }

    func returnToFeed() {
        cancelCurrentForm()
        routeHistory = []
        activeRoute = .feed
        activeTab = .feed
    }
}

private extension MarketplaceRootView {
    @ViewBuilder var professionalHome: some View {
        if let space = experience.workspace, let dashboard = professionalDashboard {
            if space.isCreator {
                UFitCreatorStudioHost(workspace: space, store: dashboard, onChooseExperience: showExperiencePicker,
                    onCreate: startOutfit, onOutfits: selectOutfits,
                    onPublicProfile: { showPublicProfile(.init(id: space.profileID, kind: .creator)) })
            } else {
                UFitBrandActivityHost(workspace: space, store: dashboard, onChooseExperience: showExperiencePicker,
                    onAddProduct: startProduct, onCatalog: selectCatalog, onOrders: { selectTab(.brandOrders) },
                    onReturns: { showBrandReturns(space) }, onSales: { showWorkspaceDashboard(space) })
            }
        } else { experienceChooser }
    }
    var experienceChooser: some View {
        UFitExperienceChooserContent(choices: experience.choices, selected: experience.selected, isLoading: experience.isLoading,
            message: experience.message, onChoose: chooseExperience, onRefresh: { Task { await experience.load() } },
            onClose: {
                if showExperienceChooser { showExperienceChooser = false; experience.dismissChoiceRequest() }
                else { chooseExperience(.customer) }
            })
    }
    func requestSignIn(keepCustomerContext: Bool) {
        preserveCustomerContextOnSignIn = keepCustomerContext; showAuthentication = true
    }
    func showExperiencePicker() {
        guard session.user != nil else { requestSignIn(keepCustomerContext: false); return }
        showExperienceChooser = true
        Task { await experience.load() }
    }
    func chooseExperience(_ selection: UFitExperienceSelection) {
        experience.choose(selection)
        guard experience.selected == selection else { return }
        applyExperienceNavigation(); showExperienceChooser = false
    }
    func applyExperienceNavigation() {
        guard appliedExperience != experience.selected else { return }
        cancelCurrentForm(); workspaces.cancelOpening(); routeHistory = []
        professionalDashboard?.cancelLoading(); professionalDashboard = nil
        appliedExperience = experience.selected
        if let space = experience.workspace, let userID = session.user?.id {
            professionalDashboard = UFitWorkspaceDashboardStore(workspace: space, session: session, userID: userID)
        }
        selectTab(experience.kind.homeTab)
    }
    func cancelCurrentForm() {
        if case .catalogForm(let form) = activeRoute { form.cancelPhotoUploads() }
        if case .outfitForm(let form) = activeRoute { form.cancelPhotoUploads() }
    }
    func outfitCollection(_ space: UFitWorkspaceReference, status: UFitOutfitStatus? = nil) -> UFitManagedOutfitsStore {
        UFitManagedOutfitsStore(scope: .init(workspace: space), title: space.isCreator ? OutfitCopy.title : AppTab.brandPublications.title,
            subtitle: space.name, access: .author, client: session.api, session: session, initialStatus: status)
    }
    func catalogCollection(_ space: UFitWorkspaceReference, status: UFitCatalogStatus? = nil) -> UFitCatalogStore {
        UFitCatalogStore(brandID: space.profileID, title: CatalogCopy.title, subtitle: space.name, access: .member,
            client: session.api, session: session, initialStatus: status)
    }
    func selectOutfits(_ status: UFitOutfitStatus?) {
        guard let space = experience.workspace, experience.canUse(space) else { return }
        selectTab(space.isCreator ? .creatorOutfits : .brandPublications)
        activeRoute = .managedOutfits(outfitCollection(space, status: status))
    }
    func selectCatalog(_ status: UFitCatalogStatus?) {
        guard let space = experience.workspace, experience.canUse(space), !space.isCreator else { return }
        selectTab(.brandCatalog); activeRoute = .catalog(catalogCollection(space, status: status))
    }
    func startOutfit() {
        selectOutfits(nil)
        if case .managedOutfits(let list) = activeRoute { showOutfitForm(list) }
    }
    func startProduct() {
        selectCatalog(nil)
        if case .catalog(let catalog) = activeRoute { showCatalogForm(catalog) }
    }
    func performProfileAction(_ action: UFitProfessionalProfileAction, space: UFitWorkspaceReference) {
        guard experience.canUse(space) else { return }
        switch action {
        case .edit: showManagedProfile(space)
        case .publicProfile:
            guard space.status == .active else { return }
            showPublicProfile(.init(id: space.profileID, kind: space.isCreator ? .creator : .brand))
        case .sales: showWorkspaceDashboard(space)
        case .commercePolicy: showBrandCommercePolicy(space)
        case .payments:
            guard space.status == .active else { return }
            routeHistory.append(activeRoute)
            let profile = UFitPaymentProfile(kind: space.isCreator ? .creator : .brand, profileID: space.profileID, name: space.name)
            activeRoute = .connect(UFitConnectStore(client: session.api, session: session, profile: profile))
        case .personalAccount:
            routeHistory.append(activeRoute); activeRoute = .account
        }
    }
    private enum ExperienceCopy {
        static let sales = String(localized: "Ventes et encaissements")
        static let returns = String(localized: "Retours et arbitrages")
    }
}

private enum AppRoute {
    case feed
    case search
    case professionalHome
    case professionalProfile
    case administratorHome
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
