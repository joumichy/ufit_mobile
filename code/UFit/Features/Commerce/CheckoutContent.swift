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
    var payment: UFitCustomerPaymentStatusDTO? = nil
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl; static let fieldSpacing: CGFloat = UFitSpace.md; static let bottom: CGFloat = 110; static let fieldHeight: CGFloat = UFitControlSize.input }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: String(localized: "Livraison et paiement"), onBack: onBack)
                .disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if step == .address { addressForm }
                    else if step == .review { review }
                    else { confirmation }
                    if isBusy { UFitLoading().frame(maxWidth: .infinity) }
                    if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).accessibilityIdentifier("checkout-message") }
                }.padding(Layout.spacing).padding(.bottom, UFitSpace.xl)
            }.scrollDismissesKeyboard(.interactively).id(step)
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }

    private var addressForm: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            Text(String(localized: "Où livrer votre sélection ?")).font(UFitTypography.title2.weight(.semibold))
            VStack(spacing: Layout.fieldSpacing) {
                field(String(localized: "Nom complet"), text: $address.fullName, content: .name)
                field(String(localized: "Adresse"), text: $address.line1, content: .streetAddressLine1)
                field(String(localized: "Complément d’adresse (facultatif)"), text: optional($address.line2), content: .streetAddressLine2)
                field(String(localized: "Code postal"), text: $address.postalCode, content: .postalCode)
                field(String(localized: "Ville"), text: $address.city, content: .addressCity)
                HStack {
                    Text(String(localized: "Pays"))
                    Spacer()
                    UFitSelection(String(localized: "Pays de livraison"), selection: $address.country, options: destinations.map { .init(value: $0.id, title: $0.name) }).tint(Color.ufitInk)
                }.frame(minHeight: Layout.fieldHeight)
                field(String(localized: "Téléphone (facultatif)"), text: optional($address.phone), content: .telephoneNumber)
                    .keyboardType(.phonePad)
            }
            Text(String(localized: "Les frais et les conditions de la marque seront affichés avant paiement."))
                .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            UFitButton(action: onReview) { Text(String(localized: "Vérifier ma commande")).frame(maxWidth: .infinity) }
                .ufitButtonStyle(.primary).disabled(isBusy || destinations.isEmpty)
        }.disabled(isBusy)
    }

    @ViewBuilder private var review: some View {
        if let summary {
            Text(String(localized: "Votre commande")).font(UFitTypography.title2.weight(.semibold))
            ForEach(lines) { line in
                HStack(alignment: .top, spacing: Layout.fieldSpacing) {
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        Text(line.name).font(UFitTypography.headline)
                        Text("\(line.variant) · \(line.quantity)").font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                    }
                    Spacer()
                    Text(line.amount).font(UFitTypography.subheadline.weight(.medium)).fixedSize()
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                Text(String(localized: "Adresse de livraison")).font(UFitTypography.headline)
                Text(address.fullName)
                Text(address.line1)
                if let line2 = address.line2, !line2.isEmpty { Text(line2) }
                Text(address.postalCode + " " + address.city)
                Text(destinations.first { $0.id == address.country }?.name ?? address.country)
            }.font(UFitTypography.subheadline)
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
            }.font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            UFitButton(action: onPay) { Text(String(localized: "Payer \(summary.total)")).frame(maxWidth: .infinity) }
                .ufitButtonStyle(.primary).disabled(isBusy)
        }
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            UFitIcon(systemName: step == .paid ? "checkmark.circle" : "clock").font(UFitTypography.largeTitle)
            Text(step == .paid ? String(localized: "Votre commande est confirmée") : payment.map { UFitCustomerPaymentCopy.title($0.state) } ?? String(localized: "Confirmation en cours"))
                .font(UFitTypography.title2.weight(.semibold))
            if let orderNumber { Text(orderNumber).font(UFitTypography.headline) }
            Text(step == .paid ? String(localized: "La marque va préparer votre sélection. Vous pourrez suivre son expédition dans vos commandes.") : payment.map { UFitCustomerPaymentCopy.detail($0.state) } ?? String(localized: "Actualisez le statut pour vérifier le paiement de cette commande."))
                .foregroundStyle(Color.ufitSecondaryText)
            UFitButton(action: step == .paid ? onFinish : onRefresh) {
                Text(step == .paid ? String(localized: "Continuer") : String(localized: "Actualiser le statut")).frame(maxWidth: .infinity)
            }.ufitButtonStyle(.primary).disabled(isBusy)
        }
    }

    private func amount(_ label: String, _ value: String) -> some View { HStack { Text(label); Spacer(); Text(value) } }
    private func field(_ label: String, text: Binding<String>, content: UITextContentType) -> some View {
        UFitTextField(label: label, text: text, contentType: content).autocorrectionDisabled()
            .accessibilityLabel(label)
    }
    private func optional(_ value: Binding<String?>) -> Binding<String> {
        Binding(get: {value.wrappedValue ?? String()}, set: {value.wrappedValue = $0.isEmpty ? nil : $0})
    }
}
