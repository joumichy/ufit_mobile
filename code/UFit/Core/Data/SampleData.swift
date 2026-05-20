import Foundation

enum SampleData {
    static let onboardingSlides = [
        OnboardingSlide(
            id: 0,
            systemImage: "sparkles",
            title: "Curated Fashion Marketplace",
            description: "Discover exclusive outfits from selected creators and independent brands. Every piece is carefully curated for quality and style."
        ),
        OnboardingSlide(
            id: 1,
            systemImage: "medal",
            title: "Selected Creators Only",
            description: "Only the best fashion curators make it to UFit. Each creator is vetted for their taste, authenticity, and styling expertise."
        ),
        OnboardingSlide(
            id: 2,
            systemImage: "bag",
            title: "Independent Brands",
            description: "Support emerging designers and sustainable fashion. We partner exclusively with independent European ateliers and ethical manufacturers."
        ),
        OnboardingSlide(
            id: 3,
            systemImage: "chart.line.uptrend.xyaxis",
            title: "Gamified Commission System",
            description: "Creators earn progressive commissions based on performance. From 8% starter rate to 15% premium tier. The more you sell, the more you earn."
        )
    ]

    static let outfits = [
        Outfit(
            id: 1,
            imageName: "unsplash-09",
            creator: "Sofia Laurent",
            creatorAvatar: "SL",
            price: "289€",
            likes: 342,
            comments: 28,
            title: "Urban Minimalism",
            products: [
                OutfitProduct(id: "oversized-shirt", systemImage: "tshirt", name: "Oversized Shirt"),
                OutfitProduct(id: "wide-pants", systemImage: "figure.walk", name: "Wide Pants"),
                OutfitProduct(id: "leather-bag", systemImage: "handbag", name: "Leather Bag"),
                OutfitProduct(id: "sandals", systemImage: "shoeprints.fill", name: "Sandals"),
                OutfitProduct(id: "sunglasses", systemImage: "sunglasses", name: "Sunglasses")
            ]
        ),
        Outfit(
            id: 2,
            imageName: "unsplash-10",
            creator: "Emma Stone",
            creatorAvatar: "ES",
            price: "198€",
            likes: 287,
            comments: 15,
            title: "Cozy Essentials",
            products: [
                OutfitProduct(id: "sweater", systemImage: "tshirt", name: "Sweater"),
                OutfitProduct(id: "jeans", systemImage: "figure.walk", name: "Jeans"),
                OutfitProduct(id: "sneakers", systemImage: "shoeprints.fill", name: "Sneakers")
            ]
        ),
        Outfit(
            id: 3,
            imageName: "unsplash-11",
            creator: "Lena M.",
            creatorAvatar: "LM",
            price: "245€",
            likes: 412,
            comments: 34,
            title: "Professional Edit",
            products: [
                OutfitProduct(id: "blazer", systemImage: "tshirt", name: "Blazer"),
                OutfitProduct(id: "trousers", systemImage: "figure.walk", name: "Trousers"),
                OutfitProduct(id: "laptop-bag", systemImage: "briefcase", name: "Laptop Bag"),
                OutfitProduct(id: "heels", systemImage: "shoeprints.fill", name: "Heels"),
                OutfitProduct(id: "watch", systemImage: "watch.analog", name: "Watch")
            ]
        )
    ]

    static let outfitPieces = [
        OutfitPiece(id: 1, name: "Oversized Linen Shirt", brand: "Atelier Minimal", price: "89€", sizes: ["XS", "S", "M", "L"]),
        OutfitPiece(id: 2, name: "High-Waisted Wide Pants", brand: "Maison Blanche", price: "120€", sizes: ["36", "38", "40", "42"]),
        OutfitPiece(id: 3, name: "Leather Crossbody Bag", brand: "Studio Craft", price: "145€", sizes: ["One Size"]),
        OutfitPiece(id: 4, name: "Minimalist Sandals", brand: "Bare Studio", price: "95€", sizes: ["37", "38", "39", "40"])
    ]

    static let creatorImages = [
        "unsplash-01",
        "unsplash-02",
        "unsplash-03",
        "unsplash-04",
        "unsplash-05",
        "unsplash-06",
        "unsplash-07",
        "unsplash-08"
    ]

    static let orders = [
        BrandOrder(id: "#UFT-2847", customer: "Marie D.", items: 2, total: "234€", status: .pending, date: "20 Mai 2026"),
        BrandOrder(id: "#UFT-2846", customer: "Lucas M.", items: 1, total: "145€", status: .shipped, date: "19 Mai 2026"),
        BrandOrder(id: "#UFT-2845", customer: "Emma R.", items: 3, total: "389€", status: .delivered, date: "18 Mai 2026"),
        BrandOrder(id: "#UFT-2844", customer: "Sophie B.", items: 2, total: "210€", status: .shipped, date: "17 Mai 2026")
    ]
}
