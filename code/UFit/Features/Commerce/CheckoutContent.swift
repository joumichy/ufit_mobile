import SwiftUI

struct UFitCheckoutContent: View {
    @Binding var address: UFitShippingAddress
    let step: UFitCheckoutStep
    let destinations: [UFitCountry]
    let lines: [UFitCartPresentationLine]
    let summary: UFitCheckoutSummary?
    let isBusy: Bool
    let message: String?
    let orderNumber: String?
    let onBack: () -> Void
    let onReview: () -> Void
    let onPay: () -> Void
    let onRefresh: () -> Void
    let onFinish: () -> Void
    private enum Layout { static let spacing: CGFloat = 24; static let fieldSpacing: CGFloat = 16; static let bottom: CGFloat = 110; static let fieldHeight: CGFloat = 48 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) { Text(String(localized: "Livraison et paiement")).font(.headline) }
                .disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if step == .address { addressForm }
                    else if step == .review { review }
                    else { confirmation }
                    if isBusy { ProgressView().frame(maxWidth: .infinity) }
                    if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted).accessibilityIdentifier("checkout-message") }
                }.padding(Layout.spacing).padding(.bottom, Layout.bottom)
            }.scrollDismissesKeyboard(.interactively).id(step)
        }.foregroundStyle(Color.ufitInk).background(Color.white)
    }

    private var addressForm: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            Text(String(localized: "Où livrer votre sélection ?")).font(.title2.weight(.semibold))
            VStack(spacing: Layout.fieldSpacing) {
                field(String(localized: "Nom complet"), text: $address.fullName, content: .name)
                field(String(localized: "Adresse"), text: $address.line1, content: .streetAddressLine1)
                field(String(localized: "Complément d’adresse (facultatif)"), text: optional($address.line2), content: .streetAddressLine2)
                field(String(localized: "Code postal"), text: $address.postalCode, content: .postalCode)
                field(String(localized: "Ville"), text: $address.city, content: .addressCity)
                HStack {
                    Text(String(localized: "Pays"))
                    Spacer()
                    Picker(String(localized: "Pays de livraison"), selection: $address.country) {
                        ForEach(destinations) { destination in Text(destination.name).tag(destination.id) }
                    }.tint(Color.ufitInk)
                }.frame(minHeight: Layout.fieldHeight)
                field(String(localized: "Téléphone (facultatif)"), text: optional($address.phone), content: .telephoneNumber)
                    .keyboardType(.phonePad)
            }
            Text(String(localized: "Les frais et les conditions de la marque seront affichés avant paiement."))
                .font(.callout).foregroundStyle(Color.ufitMuted)
            Button(action: onReview) { Text(String(localized: "Vérifier ma commande")).frame(maxWidth: .infinity) }
                .buttonStyle(PrimaryButtonStyle()).disabled(isBusy || destinations.isEmpty)
        }.disabled(isBusy)
    }

    @ViewBuilder private var review: some View {
        if let summary {
            Text(String(localized: "Votre commande")).font(.title2.weight(.semibold))
            ForEach(lines) { line in
                HStack(alignment: .top, spacing: Layout.fieldSpacing) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(line.name).font(.headline)
                        Text("\(line.variant) · \(line.quantity)").font(.subheadline).foregroundStyle(Color.ufitMuted)
                    }
                    Spacer()
                    Text(line.amount).font(.subheadline.weight(.medium)).fixedSize()
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Adresse de livraison")).font(.headline)
                Text(address.fullName)
                Text(address.line1)
                if let line2 = address.line2, !line2.isEmpty { Text(line2) }
                Text(address.postalCode + " " + address.city)
                Text(destinations.first { $0.id == address.country }?.name ?? address.country)
            }.font(.subheadline)
            Divider()
            VStack(spacing: Layout.fieldSpacing) {
                amount(String(localized: "Pièces"), summary.subtotal)
                amount(String(localized: "Livraison"), summary.shipping)
                amount(String(localized: "Taxes ajoutées"), summary.taxes)
                Divider()
                amount(String(localized: "Total"), summary.total).fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: Layout.fieldSpacing) {
                Text(summary.taxNotice)
                Text(summary.customsNotice)
                Text(String(localized: "Retours")).fontWeight(.semibold)
                Text(summary.returnPolicy)
                Text(summary.refundPolicy.explanation)
            }.font(.callout).foregroundStyle(Color.ufitMuted)
            Button(action: onPay) { Text(String(localized: "Payer \(summary.total)")).frame(maxWidth: .infinity) }
                .buttonStyle(PrimaryButtonStyle()).disabled(isBusy)
        }
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            Image(systemName: step == .paid ? "checkmark.circle" : "clock").font(.largeTitle)
            Text(step == .paid ? String(localized: "Votre commande est confirmée") : String(localized: "Confirmation en cours"))
                .font(.title2.weight(.semibold))
            if let orderNumber { Text(orderNumber).font(.headline) }
            Text(step == .paid ? String(localized: "La marque va préparer votre sélection. Vous pourrez suivre son expédition dans vos commandes.") : String(localized: "Nous attendons la confirmation du paiement. Vous pouvez actualiser le statut de votre commande."))
                .foregroundStyle(Color.ufitMuted)
            Button(action: step == .paid ? onFinish : onRefresh) {
                Text(step == .paid ? String(localized: "Continuer") : String(localized: "Actualiser le statut")).frame(maxWidth: .infinity)
            }.buttonStyle(PrimaryButtonStyle()).disabled(isBusy)
        }
    }

    private func amount(_ label: String, _ value: String) -> some View { HStack { Text(label); Spacer(); Text(value) } }
    private func field(_ label: String, text: Binding<String>, content: UITextContentType) -> some View {
        TextField(label, text: text).textContentType(content).autocorrectionDisabled()
            .padding(.horizontal, Layout.fieldSpacing).frame(minHeight: Layout.fieldHeight)
            .background(Color.ufitBackground).overlay(Rectangle().stroke(Color.ufitBorder))
            .accessibilityLabel(label)
    }
    private func optional(_ value: Binding<String?>) -> Binding<String> {
        Binding(get: {value.wrappedValue ?? String()}, set: {value.wrappedValue = $0.isEmpty ? nil : $0})
    }
}
