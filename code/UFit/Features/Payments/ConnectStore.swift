import Foundation
import Observation

@MainActor @Observable
final class UFitConnectStore {
    private(set) var profiles = [UFitPaymentProfile]()
    private(set) var selectedID: String?
    private(set) var countries = [UFitConnectCountry]()
    private(set) var statuses = [String: UFitConnectAccountStatus]()
    private(set) var busyIDs = Set<String>()
    private(set) var loadingProfiles = false
    private(set) var hasLoaded = false
    private(set) var messages = [String: String]()
    private(set) var loadError: String?
    private(set) var loadingCountries = false
    private(set) var countryError: String?
    private var countryDrafts = [String: String]()
    var country: String {
        get { status?.country ?? selectedID.flatMap { countryDrafts[$0] } ?? String() }
        set {
            guard let selectedID, status?.country == nil else { return }
            countryDrafts[selectedID] = newValue
        }
    }
    var browser: BrowserSession?
    struct BrowserSession: Identifiable { let id = UUID(); let url: URL }
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let requestedProfile: UFitPaymentProfile?
    @ObservationIgnored private var browserProfile: UFitPaymentProfile?
    private enum ProtocolValue { static let homeCountry = "CH"; static let secureScheme = "https"; static let scheme = "ufit"; static let callbackHost = "connect"; static let refreshPath = "/refresh"; static let returnPath = "/return" }
    init(client: UFitAPIClient, session: UFitSessionStore, profile: UFitPaymentProfile? = nil) {
        self.client = client; self.session = session; requestedProfile = profile
    }
    private enum Selection { static let single = 1; static let first = 0 }
    private enum ProfileFailure: LocalizedError {
        case unavailable
        var errorDescription: String? { String(localized: "Ce compte de versement n’est plus disponible dans cet espace. Actualisez vos accès.") }
    }
    var selected: UFitPaymentProfile? { profiles.first { $0.id == selectedID } }
    var status: UFitConnectAccountStatus? { selectedID.flatMap { statuses[$0] } }
    var message: String? { selectedID.flatMap { messages[$0] } ?? loadError }
    func load() async {
        guard !loadingProfiles, let userID = session.user?.id else { return }
        loadingProfiles = true; loadError = nil
        defer { loadingProfiles = false }
        do {
            let owned = try await client.fetchAllWorkspaceMemberships()
            guard session.user?.id == userID else { return }
            var profiles = owned.brands.filter { $0.status == .active }.map { UFitPaymentProfile(kind: .brand, profileID: $0.id, name: $0.brandName) }
            if let creator = owned.creator, creator.status == .active {
                profiles.insert(UFitPaymentProfile(kind: .creator, profileID: creator.id, name: creator.displayName), at: .zero)
            }
            if let requestedProfile { profiles = profiles.filter { $0.id == requestedProfile.id } }
            self.profiles = profiles
            hasLoaded = true
            let eligibleIDs = Set(profiles.map(\.id))
            if let selectedID, !eligibleIDs.contains(selectedID) { self.selectedID = nil }
            statuses = statuses.filter { eligibleIDs.contains($0.key) }
            messages = messages.filter { eligibleIDs.contains($0.key) }
            countryDrafts = countryDrafts.filter { eligibleIDs.contains($0.key) }
            guard requestedProfile == nil || !profiles.isEmpty else { throw ProfileFailure.unavailable }
            if let profile = selected { await select(profile) }
            else if profiles.count == Selection.single { await select(profiles[Selection.first]) }
        } catch { if session.user?.id == userID { loadError = error.localizedDescription } }
    }
    func select(_ profile: UFitPaymentProfile) async {
        guard profiles.contains(profile) else { return }
        selectedID = profile.id
        await refresh(profile)
    }
    func refresh(_ profile: UFitPaymentProfile? = nil) async {
        guard let profile = profile ?? selected, !busyIDs.contains(profile.id), let userID = session.user?.id else { return }
        busyIDs.insert(profile.id); messages[profile.id] = nil
        defer { busyIDs.remove(profile.id) }
        do {
            let status = try await client.fetchConnectStatus(profile)
            guard session.user?.id == userID else { return }
            receive(status, for: profile)
            if selectedID == profile.id { await loadCountries() }
        } catch { if session.user?.id == userID { messages[profile.id] = error.localizedDescription } }
    }
    private func receive(_ status: UFitConnectAccountStatus, for profile: UFitPaymentProfile) {
        statuses[profile.id] = status
        if status.country != nil { countryDrafts[profile.id] = nil }
    }
    func loadCountries() async {
        guard status?.country == nil, status?.canConfigure == true, !loadingCountries,
              let userID = session.user?.id else { return }
        if countries.isEmpty {
            loadingCountries = true; countryError = nil
            defer { loadingCountries = false }
            do {
                let codes = try await client.fetchConnectCountries()
                guard session.user?.id == userID else { return }
                countries = codes.map { UFitConnectCountry(id: $0, name: UFitConnectCountry.localizedName($0)) }
                    .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            } catch {
                if session.user?.id == userID { countryError = error.localizedDescription }
                return
            }
        }
        guard status?.country == nil, status?.canConfigure == true,
              !countries.contains(where: { $0.id == country }) else { return }
        country = countries.contains { $0.id == ProtocolValue.homeCountry } ? ProtocolValue.homeCountry : String()
    }
    func configure(dashboard: Bool = false) async {
        guard let profile = selected, let status = statuses[profile.id], status.canConfigure,
              messages[profile.id] == nil, !busyIDs.contains(profile.id), let userID = session.user?.id else { return }
        let selectedCountry = status.country ?? country
        guard dashboard || status.country != nil || (!loadingCountries && countryError == nil && countries.contains { $0.id == selectedCountry }) else { return }
        busyIDs.insert(profile.id); messages[profile.id] = nil
        defer { busyIDs.remove(profile.id) }
        do {
            let link = try await dashboard ? client.createConnectDashboard(profile) : client.createConnectOnboarding(profile, country: selectedCountry)
            guard session.user?.id == userID, selectedID == profile.id else { return }
            guard link.url.scheme == ProtocolValue.secureScheme else { throw UFitAPIError.invalidURL }
            browserProfile = profile
            browser = BrowserSession(url: link.url)
        } catch {
            guard session.user?.id == userID else { return }
            messages[profile.id] = error.localizedDescription
            if let current = try? await client.fetchConnectStatus(profile), session.user?.id == userID { receive(current, for: profile) }
        }
    }
    func browserClosed() async {
        guard let profile = browserProfile else { return }
        browserProfile = nil
        await refresh(profile)
    }
    func handleCallback(_ url: URL) async {
        guard url.scheme == ProtocolValue.scheme, url.host == ProtocolValue.callbackHost,
              [ProtocolValue.refreshPath, ProtocolValue.returnPath].contains(url.path), let profile = browserProfile else { return }
        browserProfile = nil; browser = nil
        await refresh(profile)
        if url.path == ProtocolValue.refreshPath, selectedID == profile.id { await configure() }
    }
}
