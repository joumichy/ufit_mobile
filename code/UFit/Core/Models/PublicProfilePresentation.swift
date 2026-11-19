import Foundation

struct UFitPublicProfileReference: Hashable {
    let id: String
    let kind: OutfitAuthor.Kind
}
struct UFitPublicProfileStat: Identifiable {
    enum Kind: String { case followers, outfits, products }
    let id: Kind
    let value: Int
    var label: String { switch id { case .followers: Copy.followers; case .outfits: Copy.outfits; case .products: Copy.products } }
    var icon: String { switch id { case .followers: Icon.followers; case .outfits: Icon.outfits; case .products: Icon.products } }
    private enum Copy { static let followers = String(localized: "Abonnés"); static let outfits = String(localized: "Tenues"); static let products = String(localized: "Pièces") }
    private enum Icon { static let followers = "person.2"; static let outfits = "square.grid.2x2"; static let products = "tag" }
}
struct UFitPublicProfileLink: Identifiable { let id: String; let label: String; let destination: URL? }
struct UFitPublicProfilePresentation {
    let reference: UFitPublicProfileReference
    let name: String
    let slug: String
    let bio: String?
    let avatarURL: String?
    let grade: String?
    let stats: [UFitPublicProfileStat]
    let links: [UFitPublicProfileLink]
    var initials: String { name.split(whereSeparator: \.isWhitespace).prefix(Initials.maximum).compactMap(\.first).map(String.init).joined().uppercased() }
    private enum Initials { static let maximum = 2 }
}
struct UFitPublicOutfitTile: Identifiable { let id: String; let title: String; let image: String; let price: String }
enum UFitPublicFollowState: Equatable { case hidden, signIn, loading, ready(Bool), failed(String) }
