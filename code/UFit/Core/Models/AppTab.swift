import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case feed, search, create, saved, profile
    var id: String { rawValue }
    var title: String {
        switch self {
        case .feed: Copy.feed
        case .search: Copy.search
        case .create: Copy.spaces
        case .saved: Copy.saved
        case .profile: Copy.account
        }
    }
    var systemImage: String {
        switch self {
        case .feed: Icon.feed
        case .search: Icon.search
        case .create: Icon.spaces
        case .saved: Icon.saved
        case .profile: Icon.account
        }
    }
    var activeSystemImage: String {
        switch self {
        case .feed: Icon.feedActive
        case .search: Icon.search
        case .create: Icon.spacesActive
        case .saved: Icon.savedActive
        case .profile: Icon.accountActive
        }
    }
    private enum Copy {
        static let feed = String(localized: "Découvrir"); static let search = String(localized: "Rechercher")
        static let spaces = String(localized: "Espaces"); static let saved = String(localized: "Favoris"); static let account = String(localized: "Compte")
    }
    private enum Icon {
        static let feed = "house"; static let feedActive = "house.fill"; static let search = "magnifyingglass"
        static let spaces = "square.grid.2x2"; static let spacesActive = "square.grid.2x2.fill"
        static let saved = "bookmark"; static let savedActive = "bookmark.fill"; static let account = "person"; static let accountActive = "person.fill"
    }
}
