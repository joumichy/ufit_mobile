import SwiftUI
import SafariServices

struct UFitConnectHost: View {
    @Bindable var store: UFitConnectStore
    let onBack: () -> Void
    var body: some View {
        UFitConnectContent(profiles: store.profiles, selectedID: store.selectedID, status: store.status, countries: store.countries,
            country: $store.country, loadingProfiles: store.loadingProfiles, busyIDs: store.busyIDs, message: store.message,
            onBack: onBack, onSelect: { profile in Task { await store.select(profile) } },
            onRefresh: { Task { if store.profiles.isEmpty { await store.load() } else { await store.refresh() } } },
            onConfigure: { Task { await store.configure() } }, onDashboard: { Task { await store.configure(dashboard: true) } })
            .task { await store.load() }
            .sheet(item: $store.browser, onDismiss: { Task { await store.browserClosed() } }) { browser in
                UFitStripeBrowser(url: browser.url).ignoresSafeArea()
            }
    }
}
private struct UFitStripeBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
