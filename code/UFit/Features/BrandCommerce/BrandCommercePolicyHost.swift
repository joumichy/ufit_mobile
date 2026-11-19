import SwiftUI

struct UFitBrandCommercePolicyHost: View {
    @Bindable var store: UFitBrandCommercePolicyStore
    let onBack: () -> Void
    var body: some View {
        Group {
            if store.hasLoaded {
                UFitBrandCommercePolicyContent(brandName: store.brandName, draft: $store.draft, countries: store.countries, currencies: store.currencies,
                    hasChanges: store.hasChanges, isLoading: store.isLoading, isSaving: store.isSaving, errors: store.errors, message: store.message,
                    onBack: onBack, onReload: { Task { await store.load() } }, onSave: { Task { await store.save() } })
            } else {
                UFitBrandCommercePreparationContent(isLoading: store.isLoading, message: store.message, onBack: onBack, onRetry: { Task { await store.load() } })
            }
        }.task { if !store.hasLoaded { await store.load() } }
    }
}
