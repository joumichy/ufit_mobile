import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case feed
    case search
    case create
    case orders
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed: "Feed"
        case .search: "Search"
        case .create: "Create"
        case .orders: "Orders"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .feed: "house"
        case .search: "magnifyingglass"
        case .create: "plus.circle"
        case .orders: "bag"
        case .profile: "person"
        }
    }

    var activeSystemImage: String {
        switch self {
        case .feed: "house.fill"
        case .search: "magnifyingglass"
        case .create: "plus.circle.fill"
        case .orders: "bag.fill"
        case .profile: "person.fill"
        }
    }
}
