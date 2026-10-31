import SwiftUI

struct UFitConnectContent: View {
    let profiles: [UFitPaymentProfile]
    let selectedID: String?
    let status: UFitConnectAccountStatus?
    let countries: [UFitConnectCountry]
    @Binding var country: String
    let loadingProfiles: Bool
    let busyIDs: Set<String>
    let message: String?
    let onBack: () -> Void
    let onSelect: (UFitPaymentProfile) -> Void
    let onRefresh: () -> Void
    let onConfigure: () -> Void
    let onDashboard: () -> Void
    private enum Copy {
        static let title = String(localized: "Paiements et versements")
        static let empty = String(localized: "Aucun espace de vente")
        static let icon = "creditcard"
        static let test = String(localized: "Mode test")
        static let country = String(localized: "Pays d’établissement")
        static let immutable = String(localized: "Le pays du compte Stripe ne pourra pas être modifié.")
        static let start = String(localized: "Continuer sur Stripe")
        static let dashboard = String(localized: "Gérer mon compte Stripe")
        static let refresh = String(localized: "Actualiser")
        static let required = String(localized: "La configuration Stripe est nécessaire avant toute vente ou tout versement.")
        static let owner = String(localized: "Seul le propriétaire de la marque peut configurer ce compte.")
        static let transfers = String(localized: "Réception des fonds")
        static let payouts = String(localized: "Versements bancaires")
        static let enabled = String(localized: "Activés")
        static let pending = String(localized: "À activer")
        static let selected = "checkmark"
        static let disclosure = "chevron.right"
    }
    private enum Layout { static let spacing: CGFloat = 24; static let row: CGFloat = 14; static let touch: CGFloat = 44; static let bottom: CGFloat = 110; static let radius: CGFloat = 12; static let title: CGFloat = 30; static let pillVertical: CGFloat = 7; static let single = 1 }
    private var selected: UFitPaymentProfile? { profiles.first { $0.id == selectedID } }
    private var isBusy: Bool { selectedID.map(busyIDs.contains) ?? false }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                if loadingProfiles || isBusy { ProgressView().frame(minWidth: Layout.touch, minHeight: Layout.touch) }
                else { Button(Copy.refresh, action: onRefresh).frame(minHeight: Layout.touch) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(Copy.title).font(.system(size: Layout.title, design: .serif))
                    if profiles.count > Layout.single {
                        VStack(spacing: .zero) {
                            ForEach(profiles) { profile in
                                Button { onSelect(profile) } label: {
                                    HStack(spacing: Layout.row) {
                                        VStack(alignment: .leading) { Text(profile.name).font(.headline); Text(profile.kind.label).font(.subheadline).foregroundStyle(Color.ufitMuted) }
                                        Spacer()
                                        if busyIDs.contains(profile.id) { ProgressView() }
                                        else { Image(systemName: profile.id == selectedID ? Copy.selected : Copy.disclosure) }
                                    }.frame(minHeight: Layout.touch).padding(.vertical, Layout.row)
                                }.buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                    if let selected {
                        if profiles.count == Layout.single { Text(selected.name).font(.title3.weight(.semibold)) }
                        if let status { account(status) }
                    } else if !loadingProfiles {
                        ContentUnavailableView(Copy.empty, systemImage: Copy.icon)
                    }
                    if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted) }
                }.padding(Layout.spacing).padding(.bottom, Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.white)
    }
    private func account(_ status: UFitConnectAccountStatus) -> some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            if !status.liveMode { Text(Copy.test).font(.caption.weight(.semibold)).padding(.horizontal, Layout.row).padding(.vertical, Layout.pillVertical).background(Color.ufitBackground, in: Capsule()) }
            Text(status.stage.label).font(.title2.weight(.medium))
            if status.stage != .ready { Text(Copy.required).font(.callout).foregroundStyle(Color.ufitMuted) }
            if let selectedCountry = status.country {
                VStack(alignment: .leading, spacing: Layout.row) {
                    Text(Copy.country).font(.subheadline.weight(.medium))
                    Text(countries.first { $0.id == selectedCountry }?.name ?? selectedCountry)
                }
            } else if status.canConfigure {
                VStack(alignment: .leading, spacing: Layout.row) {
                    Text(Copy.country).font(.subheadline.weight(.medium))
                    Picker(Copy.country, selection: $country) { ForEach(countries) { Text($0.name).tag($0.id) } }
                        .labelsHidden().pickerStyle(.menu).tint(Color.ufitInk).frame(minHeight: Layout.touch).disabled(isBusy)
                    Text(Copy.immutable).font(.caption).foregroundStyle(Color.ufitMuted)
                }
            }
            Divider()
            capability(Copy.transfers, status.transfersEnabled)
            capability(Copy.payouts, status.payoutsEnabled)
            if status.canConfigure {
                if status.stage != .ready {
                    Button(action: onConfigure) { Text(Copy.start).frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle()).disabled(isBusy || (status.country == nil && country.isEmpty))
                }
                if status.stage == .ready || status.stage == .restricted {
                    Button(Copy.dashboard, action: onDashboard).frame(minHeight: Layout.touch).disabled(isBusy)
                }
            } else { Text(Copy.owner).font(.callout).foregroundStyle(Color.ufitMuted) }
        }
    }
    private func capability(_ title: String, _ enabled: Bool) -> some View {
        HStack { Text(title).font(.subheadline); Spacer(); Text(enabled ? Copy.enabled : Copy.pending).font(.subheadline.weight(.medium)) }
    }
}
