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
    var recoveryAmount: String? = nil
    var canReplay = false
    var requiresNewReview = false
    var purchaseAvailable = false
    var onReplay: () -> Void = {}
    var onReload: () -> Void = {}
    var addressOptions: AnyView? = nil
    var savedAddress: UFitShippingAddress? = nil
    var savedAddressID: String? = nil
    var onEditSavedAddress: () -> Void = {}
    var isLoadingAddress = false
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl; static let fieldSpacing: CGFloat = UFitSpace.md; static let bottom: CGFloat = 110; static let fieldHeight: CGFloat = UFitControlSize.input }
    private struct ScrollIdentity: Hashable { let step: UFitCheckoutStep; let addressID: String? }
    private var resumesPayment: Bool { payment?.state.canResume == true }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: String(localized: "Livraison et paiement"), onBack: onBack)
                .disabled(isBusy)
            if step == .address || step == .review, let message {
                Group {
                    if requiresNewReview { UFitNotice(message: message) }
                    else { UFitNotice(message: message, kind: .error) }
                }.padding(.horizontal, Layout.spacing).padding(.top, UFitSpace.md)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if step == .address && isLoadingAddress { UFitLoading(String(localized: "Préparation de la livraison")) }
                    else if step == .address { addressForm }
                    else if step == .review { review }
                    else if step == .recovery {
                        UFitCheckoutRecoveryContent(amount: recoveryAmount, canReplay: canReplay, isBusy: isBusy,
                            message: message, onVerify: onReload, onReplay: onReplay)
                    }
                    else { confirmation }
                    if step != .recovery {
                        if isBusy && step != .address && step != .review { UFitLoading().frame(maxWidth: .infinity) }
                        if let message, step != .address && step != .review { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).accessibilityIdentifier("checkout-message") }
                        if step == .address && destinations.isEmpty && message != nil {
                            UFitActionButton(title: UFitCheckoutRecoveryCopy.deliveryRetry, kind: .secondary, isBusy: isBusy, action: onReload)
                        }
                    }
                }.padding(Layout.spacing).padding(.bottom, UFitSpace.xl)
            }.scrollDismissesKeyboard(.interactively).id(ScrollIdentity(step: step, addressID: savedAddressID))
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }

    private var addressForm: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            Text(String(localized: "Où livrer votre sélection ?")).font(UFitTypography.title2.weight(.semibold))
            if let savedAddress {
                UFitPostalAddress(address: savedAddress)
                if !destinations.contains(where: { $0.id == savedAddress.country }) {
                    UFitNotice(message: String(localized: "Cette adresse n’est pas desservie par la marque."))
                }
                UFitActionButton(title: String(localized: "Modifier pour cet achat"), kind: .secondary, action: onEditSavedAddress)
            } else { UFitShippingAddressFields(address: $address, countries: destinations) }
            if let addressOptions { addressOptions }
            Text(String(localized: "Les frais et les conditions de la marque seront affichés avant paiement."))
                .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            UFitActionButton(title: String(localized: "Vérifier ma commande"), isBusy: isBusy,
                disabled: !destinations.contains(where: { $0.id == address.country }), action: onReview)
        }.disabled(isBusy)
    }

    @ViewBuilder private var review: some View {
        if let summary {
            if !purchaseAvailable { UFitNotice(message: UFitCheckoutAvailabilityCopy.unavailable) }
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
            paymentAction(total: summary.total)
        }
    }

    @ViewBuilder private func paymentAction(total: String) -> some View {
        if !purchaseAvailable {
            UFitActionButton(title: UFitCheckoutAvailabilityCopy.recheck, isBusy: isBusy, action: onReview)
        } else if resumesPayment {
            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                Text(UFitCustomerPaymentCopy.methodChoice).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                UFitActionButton(title: UFitCustomerPaymentCopy.chooseMethod, isBusy: isBusy, action: onPay)
            }
        } else {
            UFitActionButton(title: String(localized: "Payer \(total)"), isBusy: isBusy, action: onPay)
        }
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            UFitIcon(systemName: step == .paid ? "checkmark.circle" : "clock").font(UFitTypography.largeTitle)
            Text(step == .paid ? String(localized: "Votre commande est confirmée") : payment.map { UFitCustomerPaymentCopy.title($0.state) } ?? String(localized: "Suivi du paiement"))
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
}
