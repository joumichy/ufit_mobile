import SwiftUI

struct UFitConnectHost: View {
    @Bindable var store: UFitConnectStore
    let onBack: () -> Void
    var body: some View {
        UFitConnectContent(profiles: store.profiles, selectedID: store.selectedID, status: store.status, countries: store.countries,
            country: $store.country, loadingProfiles: store.loadingProfiles, hasLoaded: store.hasLoaded,
            loadingCountries: store.loadingCountries, countryError: store.countryError, busyIDs: store.busyIDs, message: store.message,
            onBack: onBack, onSelect: { profile in Task { await store.select(profile) } },
            onRefresh: { Task { if store.selected == nil { await store.load() } else { await store.refresh() } } },
            onRetryCountries: { Task { await store.loadCountries() } },
            onConfigure: { Task { await store.configure() } }, onDashboard: { Task { await store.configure(dashboard: true) } })
            .task { await store.load() }
            .ufitSheet(item: $store.browser, onDismiss: { Task { await store.browserClosed() } }) { browser in
                UFitStripeBrowser(url: browser.url).ignoresSafeArea()
            }
    }
}
