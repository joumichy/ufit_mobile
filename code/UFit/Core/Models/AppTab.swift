import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case feed
    case search
    case create
    case saved
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed: "Feed"
        case .search: "Search"
        case .create: "Create"
        case .saved: "Saved"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .feed: "house"
        case .search: "magnifyingglass"
        case .create: "plus.circle"
        case .saved: "bookmark"
        case .profile: "person"
        }
    }

    var activeSystemImage: String {
        switch self {
        case .feed: "house.fill"
        case .search: "magnifyingglass"
        case .create: "plus.circle.fill"
        case .saved: "bookmark.fill"
        case .profile: "person.fill"
        }
    }
}
