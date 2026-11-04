import SwiftUI

struct UFitShippingAddressBookHost: View {
    @Bindable var store: UFitShippingAddressBookStore
    let onBack: () -> Void
    var onSelect: ((UFitShippingAddressItem) -> Void)? = nil
    var destinations: [UFitCountry]? = nil
    @State private var editor: Editor?
    @State private var removingID: String?
    private struct Editor: Identifiable { let id: UUID; let item: UFitShippingAddressItem? }
    var body: some View {
        Group {
            if let editor {
                UFitShippingAddressEditor(store: store, original: editor.item,
                    onBack: { self.editor = nil }, onSaved: { self.editor = nil }).id(editor.id)
            } else { book }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task { await store.load() }
    }
    private var book: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: String(localized: "Mes adresses"), onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    Text(onSelect == nil ? String(localized: "Prêt pour votre prochaine sélection.") : String(localized: "Choisir une adresse de livraison"))
                        .font(UFitTypography.title2.weight(.regular))
                    if let error = store.loadError {
                        UFitNotice(message: error, kind: .error)
                        UFitActionButton(title: String(localized: "Actualiser le carnet"), kind: .secondary, isBusy: store.isLoading) { Task { await store.load() } }
                    }
                    if store.isLoading { UFitLoading(String(localized: "Chargement de vos adresses")) }
                    UFitShippingAddressRecovery(store: store)
                    if store.hasLoaded, store.items.isEmpty, store.loadError == nil {
                        UFitEmptyState(title: String(localized: "Votre première adresse"),
                            message: String(localized: "Enregistrez vos informations de livraison pour les retrouver lors de vos prochains achats."), symbol: "mappin.and.ellipse")
                    }
                    ForEach(store.items) { item in card(item) }
                    if store.nextCursor != nil {
                        UFitActionButton(title: String(localized: "Voir plus d’adresses"), kind: .secondary, isBusy: store.isLoading) { Task { await store.load(more: true) } }
                    }
                    if store.hasLoaded {
                        UFitActionButton(title: String(localized: "Ajouter une adresse"), kind: onSelect == nil ? .primary : .secondary) { editor = .init(id: UUID(), item: nil) }
                    }
                }.padding(UFitSpace.page)
            }
        }
    }
    private func card(_ item: UFitShippingAddressItem) -> some View {
        let available = destinations.map { $0.contains { $0.id == item.shippingAddress.country } } ?? true
        return VStack(alignment: .leading, spacing: UFitSpace.md) {
            if item.id == store.defaultID {
                Label(String(localized: "Par défaut"), systemImage: "checkmark.circle")
                    .font(UFitTypography.caption.weight(.semibold)).foregroundStyle(Color.ufitSecondaryText)
            }
            UFitPostalAddress(address: item.shippingAddress)
            if let onSelect {
                if !available { UFitNotice(message: String(localized: "La marque ne livre pas dans ce pays pour votre sélection.")) }
                UFitActionButton(title: String(localized: "Livrer à cette adresse"), kind: .secondary, disabled: !available) { onSelect(item) }
            }
            if onSelect == nil {
                if removingID != item.id { HStack(spacing: UFitSpace.sm) {
                    UFitButton(String(localized: "Modifier")) { editor = .init(id: UUID(), item: item) }
                        .ufitButtonStyle(.secondary, compact: true).disabled(store.busyID == item.id)
                    UFitButton(String(localized: "Retirer"), role: .destructive) { removingID = item.id }
                        .ufitButtonStyle(.secondary, compact: true).disabled(store.busyID == item.id)
                } }
                if removingID == item.id {
                    Text(String(localized: "Retirer cette adresse du carnet ? Vos commandes sont conservées."))
                        .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    UFitActionButton(title: String(localized: "Confirmer le retrait"), kind: .secondary, role: .destructive,
                        isBusy: store.busyID == item.id) { Task { await store.remove(item.id); removingID = nil } }
                    UFitActionButton(title: String(localized: "Conserver cette adresse"), kind: .secondary,
                        disabled: store.busyID == item.id) { removingID = nil }
                } else {
                    UFitActionButton(title: item.id == store.defaultID ? String(localized: "Ne plus utiliser par défaut") : String(localized: "Utiliser par défaut"),
                        kind: .secondary, isBusy: store.busyID == item.id) {
                        Task { await store.setDefault(item.id == store.defaultID ? nil : item.id) }
                    }
                }
            }
        }.padding(UFitSpace.lg).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ufitBackground, in: RoundedRectangle(cornerRadius: UFitRadius.card))
    }
}

struct UFitShippingAddressRecovery: View {
    @Bindable var store: UFitShippingAddressBookStore
    var onResolved: () -> Void = {}
    var body: some View {
        if let message = store.message { UFitNotice(message: message) }
        if store.pending != nil, store.busyID == nil || store.isResuming {
            UFitActionButton(title: String(localized: "Reprendre la modification"), kind: .secondary, isBusy: store.isResuming) {
                Task { if await store.resume() { onResolved() } }
            }
        }
    }
}

private struct UFitShippingAddressEditor: View {
    @Bindable var store: UFitShippingAddressBookStore
    let original: UFitShippingAddressItem?
    let onBack: () -> Void
    let onSaved: () -> Void
    @State private var address = UFitShippingAddress()
    @State private var makeDefault = false
    @State private var saving = false
    @State private var initialized = false
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: original == nil ? String(localized: "Nouvelle adresse") : String(localized: "Modifier l’adresse"), onBack: onBack).disabled(saving)
            if store.message != nil || store.loadError != nil || store.needsRefresh || store.storageFailed {
                VStack(alignment: .leading, spacing: UFitSpace.md) {
                    UFitShippingAddressRecovery(store: store, onResolved: onSaved)
                    if let message = store.loadError { UFitNotice(message: message, kind: .error) }
                    if store.needsRefresh || store.storageFailed || store.loadError != nil {
                        UFitActionButton(title: String(localized: "Actualiser le carnet"), kind: .secondary, isBusy: store.isLoading) { Task { await store.load() } }
                    }
                }.padding(.horizontal, UFitSpace.page).padding(.top, UFitSpace.md)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    if let message = store.countryError {
                        UFitNotice(message: message, kind: .error)
                        UFitActionButton(title: String(localized: "Recharger les pays"), kind: .secondary,
                            isBusy: store.isLoadingCountries) { Task { await store.loadCountries() } }
                    }
                    if store.isLoadingCountries { UFitLoading(String(localized: "Chargement des pays")) }
                    UFitShippingAddressFields(address: $address, countries: store.countries).disabled(store.pending != nil)
                    if original == nil || original?.id != store.defaultID {
                        UFitToggle(String(localized: "Utiliser par défaut pour mes achats"), isOn: $makeDefault).disabled(store.pending != nil)
                    }
                    if let original, original.id == store.defaultID {
                        Text(String(localized: "Cette adresse est utilisée par défaut. Vous pouvez retirer ce choix depuis le carnet."))
                            .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    }
                    UFitActionButton(title: String(localized: "Enregistrer l’adresse"), isBusy: saving,
                        disabled: store.countries.isEmpty || store.pending != nil || store.storageFailed || store.needsRefresh) {
                        saving = true
                        Task {
                            let saved = await store.save(address: address, id: original?.id, makeDefault: makeDefault)
                            saving = false
                            if saved { onSaved() }
                        }
                    }
                }.padding(UFitSpace.page).disabled(saving)
            }.scrollDismissesKeyboard(.interactively)
        }.task {
            if !initialized {
                store.beginEditing()
                if let original { address = original.shippingAddress }
                initialized = true
            }
            await store.loadCountries()
        }
    }
}
