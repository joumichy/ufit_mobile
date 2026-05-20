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
        VStack(spacing: 0) {
            DetailHeader(onBack: onBack) {
                HStack(spacing: 18) {
                    Image(systemName: "square.and.arrow.up")
                    Image(systemName: "heart")
                }
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(Color.ufitInk)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OutfitHeroImage(imageName: resolvedOutfit.imageName)
                    OutfitSummary(outfit: resolvedOutfit)
                    OutfitPiecesSection(pieces: pieces)
                    CheckoutSummary(total: resolvedOutfit.price)
                    Button("Acheter le look complet", action: presentCheckout)
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 104)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
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

private struct OutfitHeroImage: View {
    let imageName: String

    var body: some View {
        FashionImage(source: imageName)
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .clipped()
            .background(Color.ufitSecondary)
    }
}

private struct OutfitSummary: View {
    let outfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(outfit.title)
                .font(.system(size: 27, weight: .regular))
            Text("By \(outfit.creator)")
                .font(.system(size: 15))
                .foregroundStyle(Color.ufitMuted)
            Text(outfit.description)
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Color.ufitMuted)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }
}

private struct OutfitPiecesSection: View {
    let pieces: [OutfitPiece]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Complete the Look")
                .font(.system(size: 20, weight: .medium))
                .padding(.horizontal, 24)

            ForEach(Array(pieces.enumerated()), id: \.element.id) { index, piece in
                OutfitPieceCard(index: index + 1, piece: piece)
                    .padding(.horizontal, 24)
            }
        }
    }
}

private struct CheckoutSummary: View {
    let total: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal")
                    .foregroundStyle(Color.ufitMuted)
                Spacer()
                Text(total)
            }

            Divider()

            HStack {
                Text("Total")
                Spacer()
                Text(total)
                    .font(.system(size: 22, weight: .medium))
            }
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.ufitInk)
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }
}

private struct CheckoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var shippingAddress: UFitShippingAddress
    let isCheckingOut: Bool
    let message: String?
    let onCheckout: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Shipping") {
                    TextField("Full name", text: $shippingAddress.fullName)
                    TextField("Address", text: $shippingAddress.line1)
                    TextField("Postal code", text: $shippingAddress.postalCode)
                    TextField("City", text: $shippingAddress.city)
                    TextField("Country", text: $shippingAddress.country)
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.ufitMuted)
                    }
                }
            }
            .navigationTitle("Checkout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCheckingOut ? "Preparing..." : "Pay") {
                        onCheckout()
                    }
                    .disabled(isCheckingOut || shippingAddress.fullName.isEmpty || shippingAddress.line1.isEmpty || shippingAddress.postalCode.isEmpty || shippingAddress.city.isEmpty)
                }
            }
        }
    }
}

#Preview {
    OutfitDetailView(store: MarketplaceStore.live(), outfit: SampleData.outfits[0], onBack: {})
}
