import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case feed, search, saved, cart, profile
    case creatorStudio, creatorOutfits, creatorEarnings, creatorProfile
    case brandActivity, brandCatalog, brandOrders, brandPublications, brandProfile
    case adminHome, adminApplications, adminProducts, adminOutfits
    var id: String { rawValue }
    var title: String {
        switch self {
        case .feed: Copy.feed; case .search: Copy.search; case .saved: Copy.saved; case .cart: Copy.cart; case .profile: Copy.account
        case .creatorStudio: Copy.studio; case .creatorOutfits: Copy.outfits; case .creatorEarnings: Copy.earnings; case .creatorProfile: Copy.creatorProfile
        case .brandActivity: Copy.activity; case .brandCatalog: Copy.catalog; case .brandOrders: Copy.orders; case .brandPublications: Copy.publications; case .brandProfile: Copy.brand
        case .adminHome: Copy.review; case .adminApplications: Copy.applications; case .adminProducts: Copy.products; case .adminOutfits: Copy.outfits
        }
    }
    var systemImage: String {
        switch self {
        case .feed: Icon.home; case .search: Icon.search; case .saved: Icon.saved; case .cart: Icon.cart; case .profile: Icon.account
        case .creatorStudio: Icon.studio; case .creatorOutfits, .brandPublications, .adminOutfits: Icon.outfits
        case .creatorEarnings: Icon.earnings; case .creatorProfile: Icon.creator
        case .brandActivity: Icon.activity; case .brandCatalog, .adminProducts: Icon.catalog; case .brandOrders: Icon.orders; case .brandProfile: Icon.brand
        case .adminHome: Icon.review; case .adminApplications: Icon.applications
        }
    }
    var activeSystemImage: String {
        switch self {
        case .feed: Icon.homeActive; case .saved: Icon.savedActive; case .cart: Icon.cartActive; case .profile: Icon.accountActive
        case .creatorStudio: Icon.studioActive; case .creatorOutfits, .brandPublications, .adminOutfits: Icon.outfitsActive
        case .creatorProfile: Icon.creatorActive; case .brandCatalog, .adminProducts: Icon.catalogActive
        case .brandOrders: Icon.ordersActive; case .brandProfile: Icon.brandActive; case .adminHome: Icon.reviewActive
        case .search, .creatorEarnings, .brandActivity, .adminApplications: systemImage
        }
    }
    private enum Copy {
        static let feed = String(localized: "Découvrir"); static let search = String(localized: "Rechercher")
        static let saved = String(localized: "Favoris"); static let cart = String(localized: "Panier"); static let account = String(localized: "Compte")
        static let studio = String(localized: "Studio"); static let outfits = String(localized: "Tenues"); static let earnings = String(localized: "Revenus")
        static let creatorProfile = String(localized: "Profil"); static let activity = String(localized: "Activité"); static let catalog = String(localized: "Catalogue")
        static let orders = String(localized: "Commandes"); static let publications = String(localized: "Publications"); static let brand = String(localized: "Marque")
        static let review = String(localized: "À traiter"); static let applications = String(localized: "Candidatures"); static let products = String(localized: "Produits")
    }
    private enum Icon {
        static let home = "house"; static let homeActive = "house.fill"; static let search = "magnifyingglass"
        static let saved = "bookmark"; static let savedActive = "bookmark.fill"; static let cart = "bag"; static let cartActive = "bag.fill"
        static let account = "person"; static let accountActive = "person.fill"; static let studio = "rectangle.grid.1x2"; static let studioActive = "rectangle.grid.1x2.fill"
        static let outfits = "rectangle.stack"; static let outfitsActive = "rectangle.stack.fill"; static let earnings = "chart.line.uptrend.xyaxis"
        static let creator = "person.crop.square"; static let creatorActive = "person.crop.square.fill"; static let activity = "chart.bar.xaxis"
        static let catalog = "tag"; static let catalogActive = "tag.fill"; static let orders = "shippingbox"; static let ordersActive = "shippingbox.fill"
        static let brand = "storefront"; static let brandActive = "storefront.fill"; static let review = "checkmark.shield"; static let reviewActive = "checkmark.shield.fill"
        static let applications = "person.text.rectangle"
    }
}
