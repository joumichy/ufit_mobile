import SwiftUI
import StripePaymentSheet

struct UFitCheckoutHost: View {
    @Bindable var store: UFitCheckoutStore
    let onBack: () -> Void
    let onFinish: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var choosesAddress = false
    var body: some View {
        Group {
            if choosesAddress {
                UFitShippingAddressBookHost(store: store.addressBook, onBack: { choosesAddress = false },
                    onSelect: { store.selectAddress($0); choosesAddress = false }, destinations: store.destinations)
            } else {
                UFitCheckoutContent(address: $store.address, step: store.step, destinations: store.destinations,
                    lines: store.lines, summary: store.summary, isBusy: store.isBusy, message: store.message,
                    orderNumber: store.order?.orderNumber, onBack: {
                        if store.order != nil { onFinish() }
                        else if store.step == .review && !store.hasPreparedOrder { store.editAddress() } else { onBack() }
                    }, onReview: { Task { await store.review() } },
                    onPay: { Task { _ = await store.preparePayment() } },
                    onRefresh: { Task { await store.refreshConfirmation() } }, onFinish: onFinish, payment: store.payment,
                    recoveryAmount: store.recoveryAmount, canReplay: store.canReplay, requiresNewReview: store.requiresNewReview,
                    purchaseAvailable: store.purchaseAvailable,
                    onReplay: { Task { await store.replay() } }, onReload: { Task { await store.load() } },
                    addressOptions: AnyView(addressOptions), savedAddress: store.selectedAddressID == nil ? nil : store.address,
                    savedAddressID: store.selectedAddressID,
                    onEditSavedAddress: store.useManualAddress, isLoadingAddress: store.isLoadingAddress)
                    .task { await store.load() }
                    .onChange(of: store.needsOrderDetails) { _, needed in if needed { onFinish() } }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active && store.paymentSheet == nil {
                            if store.step == .confirming { Task { await store.refreshConfirmation() } }
                            else if store.step == .recovery { Task { await store.load() } }
                        }
                    }
                    .background {
                        if let sheet = store.paymentSheet {
                            UFitStripePaymentPresentation(sheet: sheet) { result in
                                Task { await store.paymentFinished(result) }
                            }.id(ObjectIdentifier(sheet))
                        }
                    }
            }
        }
    }
    private var addressOptions: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            if store.addressBook.loadError != nil {
                Text(String(localized: "Votre carnet est indisponible. Vous pouvez saisir une adresse pour cet achat."))
                    .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            }
            UFitActionButton(title: String(localized: "Choisir dans mes adresses"), kind: .secondary) { choosesAddress = true }
            if store.selectedAddressID == nil {
                UFitToggle(String(localized: "Enregistrer cette adresse pour mes prochains achats"), isOn: $store.saveAddress)
                if store.saveAddress {
                    UFitToggle(String(localized: "Utiliser par défaut"), isOn: $store.makeAddressDefault)
                }
            }
        }
    }
}
