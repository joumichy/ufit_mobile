import SwiftUI

struct UFitApplicationsHost: View {
    let store: UFitApplicationsStore
    let onBack: () -> Void
    let onApply: (UFitApplicationKind, UFitApplicationDocument?) -> Void
    let onPayments: () -> Void
    var body: some View {
        UFitApplicationsContent(creator: store.applications?.creator, brand: store.applications?.brand,
            canApplyCreator: store.applications?.canApplyCreator ?? false, canApplyBrand: store.applications?.canApplyBrand ?? false,
            hasLoaded: store.applications != nil, isLoading: store.isLoading, message: store.message,
            onBack: onBack, onRefresh: { Task { await store.load() } }, onApply: { onApply($0, nil) },
            onCorrect: { onApply($0.metadata.type, $0) }, onPayments: onPayments)
            .task { await store.load() }
    }
}
struct UFitApplicationFormHost: View {
    @Bindable var store: UFitApplicationFormStore
    let onBack: () -> Void
    let onSubmitted: () -> Void
    var body: some View {
        UFitApplicationFormContent(kind: store.kind, values: $store.values, countries: store.countries, errors: store.errors,
            isBusy: store.isBusy, isLoadingCountries: store.loadingCountries, isCorrection: store.correcting != nil, message: store.message,
            onBack: onBack, onSubmit: { Task { if await store.submit() { onSubmitted() } } },
            onRetryCountries: { Task { await store.loadCountries() } })
            .task { await store.loadCountries() }
    }
}

struct UFitOwnedApplicationHost: View {
    let store: UFitOwnedApplicationStore
    let onBack: () -> Void
    let onCorrect: (UFitApplicationKind, UFitApplicationDocument?) -> Void
    let onPayments: () -> Void
    var body: some View {
        UFitApplicationsContent(creator: store.kind == .creator ? store.document : nil, brand: store.kind == .brand ? store.document : nil,
            canApplyCreator: false, canApplyBrand: false, hasLoaded: store.document != nil,
            isLoading: store.isLoading, message: store.message, onBack: onBack,
            onRefresh: { Task { await store.load() } }, onApply: { _ in },
            onCorrect: { onCorrect($0.metadata.type, $0) }, onPayments: onPayments, focusedKind: store.kind)
            .task { await store.load() }
    }
}
