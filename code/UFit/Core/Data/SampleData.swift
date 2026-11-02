import Foundation

enum SampleData {
    static let outfits = [
        Outfit(
            id: "sample-urban-minimalism",
            imageName: "unsplash-09",
            creator: "Sofia Laurent",
            creatorAvatar: "SL",
            author: nil,
            price: "289€",
            title: "Urban Minimalism",
            description: "Effortless elegance meets street style. A carefully curated selection of premium pieces from independent European ateliers.",
            sourceCreatorId: nil,
            sourceOutfitId: "sample-urban-minimalism",
            products: [
                OutfitProduct(id: "oversized-shirt", systemImage: "tshirt", name: "Oversized Shirt", productID: nil, brandID: nil),
                OutfitProduct(id: "wide-pants", systemImage: "figure.walk", name: "Wide Pants", productID: nil, brandID: nil),
                OutfitProduct(id: "leather-bag", systemImage: "handbag", name: "Leather Bag", productID: nil, brandID: nil),
                OutfitProduct(id: "sandals", systemImage: "shoeprints.fill", name: "Sandals", productID: nil, brandID: nil),
                OutfitProduct(id: "sunglasses", systemImage: "sunglasses", name: "Sunglasses", productID: nil, brandID: nil)
            ],
            pieces: []
        ),
        Outfit(
            id: "sample-cozy-essentials",
            imageName: "unsplash-10",
            creator: "Emma Stone",
            creatorAvatar: "ES",
            author: nil,
            price: "198€",
            title: "Cozy Essentials",
            description: "Soft textures and quiet everyday pieces for a grounded silhouette.",
            sourceCreatorId: nil,
            sourceOutfitId: "sample-cozy-essentials",
            products: [
                OutfitProduct(id: "sweater", systemImage: "tshirt", name: "Sweater", productID: nil, brandID: nil),
                OutfitProduct(id: "jeans", systemImage: "figure.walk", name: "Jeans", productID: nil, brandID: nil),
                OutfitProduct(id: "sneakers", systemImage: "shoeprints.fill", name: "Sneakers", productID: nil, brandID: nil)
            ],
            pieces: []
        ),
        Outfit(
            id: "sample-professional-edit",
            imageName: "unsplash-11",
            creator: "Lena M.",
            creatorAvatar: "LM",
            author: nil,
            price: "245€",
            title: "Professional Edit",
            description: "Tailored essentials with a polished rhythm for weekday movement.",
            sourceCreatorId: nil,
            sourceOutfitId: "sample-professional-edit",
            products: [
                OutfitProduct(id: "blazer", systemImage: "tshirt", name: "Blazer", productID: nil, brandID: nil),
                OutfitProduct(id: "trousers", systemImage: "figure.walk", name: "Trousers", productID: nil, brandID: nil),
                OutfitProduct(id: "laptop-bag", systemImage: "briefcase", name: "Laptop Bag", productID: nil, brandID: nil),
                OutfitProduct(id: "heels", systemImage: "shoeprints.fill", name: "Heels", productID: nil, brandID: nil),
                OutfitProduct(id: "watch", systemImage: "watch.analog", name: "Watch", productID: nil, brandID: nil)
            ],
            pieces: []
        )
    ]

    static let outfitPieces = [
        OutfitPiece(id: "sample-piece-shirt", name: "Oversized Linen Shirt", brand: "Atelier Minimal", price: "89€", sizes: ["XS", "S", "M", "L"], productID: nil, isRequired: true, isShoppable: true),
        OutfitPiece(id: "sample-piece-pants", name: "High-Waisted Wide Pants", brand: "Maison Blanche", price: "120€", sizes: ["36", "38", "40", "42"], productID: nil, isRequired: true, isShoppable: true),
        OutfitPiece(id: "sample-piece-bag", name: "Leather Crossbody Bag", brand: "Studio Craft", price: "145€", sizes: ["One Size"], productID: nil, isRequired: true, isShoppable: true),
        OutfitPiece(id: "sample-piece-sandals", name: "Minimalist Sandals", brand: "Bare Studio", price: "95€", sizes: ["37", "38", "39", "40"], productID: nil, isRequired: true, isShoppable: true)
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
