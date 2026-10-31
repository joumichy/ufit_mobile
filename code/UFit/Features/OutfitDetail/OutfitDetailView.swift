import SwiftUI

struct OutfitDetailView: View {
    @Environment(\.openURL) private var openURL

    let store: MarketplaceStore
    let outfit: Outfit
    let onBack: () -> Void

    @State private var resolvedOutfit: Outfit
    @State private var shippingAddress = UFitShippingAddress(
        fullName: "",
        line1: "",
        line2: nil,
        postalCode: "",
        city: "",
        country: "CH",
        phone: nil
    )
    @State private var isCheckoutPresented = false
    @State private var isCheckingOut = false
    @State private var checkoutMessage: String?

    init(store: MarketplaceStore, outfit: Outfit, onBack: @escaping () -> Void) {
        self.store = store
        self.outfit = outfit
        self.onBack = onBack
        _resolvedOutfit = State(initialValue: outfit)
    }

    var body: some View {
        OutfitDetailContentView(outfit: resolvedOutfit, pieces: pieces, onBack: onBack, onBuy: presentCheckout)
        .task(id: outfit.id) {
            resolvedOutfit = await store.detail(for: outfit)
        }
        .sheet(isPresented: $isCheckoutPresented) {
            CheckoutSheet(
                shippingAddress: $shippingAddress,
                isCheckingOut: isCheckingOut,
                message: checkoutMessage,
                onCheckout: checkout
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var pieces: [OutfitPiece] {
        resolvedOutfit.pieces.isEmpty ? SampleData.outfitPieces : resolvedOutfit.pieces
    }

    private func presentCheckout() {
        checkoutMessage = nil
        isCheckoutPresented = true
    }

    private func checkout() {
        guard !isCheckingOut else { return }
        isCheckingOut = true
        checkoutMessage = nil

        Task {
            defer { isCheckingOut = false }
            do {
                let url = try await store.checkout(outfit: resolvedOutfit, shippingAddress: shippingAddress)
                isCheckoutPresented = false
                openURL(url)
            } catch {
                checkoutMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    OutfitDetailView(store: MarketplaceStore.live(), outfit: SampleData.outfits[0], onBack: {})
}
