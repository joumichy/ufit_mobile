import SwiftUI

struct UFitConnectContent: View {
    let profiles: [UFitPaymentProfile]
    let selectedID: String?
    let status: UFitConnectAccountStatus?
    let countries: [UFitConnectCountry]
    @Binding var country: String
    let loadingProfiles: Bool
    let hasLoaded: Bool
    let busyIDs: Set<String>
    let message: String?
    let onBack: () -> Void
    let onSelect: (UFitPaymentProfile) -> Void
    let onRefresh: () -> Void
    let onConfigure: () -> Void
    let onDashboard: () -> Void
    private enum Copy {
        static let title = String(localized: "Paiements et versements")
        static let loading = String(localized: "Chargement des comptes de vente")
        static let failed = String(localized: "Espaces de vente indisponibles")
        static let retry = String(localized: "Réessayer")
        static let failureIcon = "wifi.exclamationmark"
        static let refreshIcon = "arrow.clockwise"
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
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl; static let row: CGFloat = 14; static let touch: CGFloat = UFitControlSize.touch; static let bottom: CGFloat = 110; static let radius: CGFloat = UFitRadius.field; static let title: CGFloat = UFitTypography.Size.editorial; static let pillVertical: CGFloat = 7; static let single = 1 }
    private var selected: UFitPaymentProfile? { profiles.first { $0.id == selectedID } }
    private var isBusy: Bool { selectedID.map(busyIDs.contains) ?? false }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isBusy { UFitLoading().frame(minWidth: Layout.touch, minHeight: Layout.touch) }
                else if !profiles.isEmpty {
                    UFitButton(action: onRefresh) { UFitIcon(systemName: Copy.refreshIcon).frame(width: Layout.touch, height: Layout.touch) }
                        .accessibilityLabel(Copy.refresh).disabled(loadingProfiles)
                }
            }
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.spacing) {
                        if profiles.isEmpty {
                            if loadingProfiles || (!hasLoaded && message == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                            else if let message {
                                UFitEmptyState(title: Copy.failed, message: message, symbol: Copy.failureIcon,
                                    actionTitle: Copy.retry, action: onRefresh)
                            } else { UFitEmptyState(title: Copy.empty, symbol: Copy.icon) }
                        } else {
                            if profiles.count > Layout.single {
                                VStack(spacing: .zero) {
                                    ForEach(profiles) { profile in
                                        UFitButton { onSelect(profile) } label: {
                                            HStack(spacing: Layout.row) {
                                                VStack(alignment: .leading) { Text(profile.name).font(UFitTypography.headline); Text(profile.kind.label).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText) }
                                                Spacer()
                                                if busyIDs.contains(profile.id) { UFitLoading() }
                                                else { UFitIcon(systemName: profile.id == selectedID ? Copy.selected : Copy.disclosure) }
                                            }.frame(minHeight: Layout.touch).padding(.vertical, Layout.row)
                                        }.ufitButtonStyle(.text)
                                        Divider()
                                    }
                                }
                            }
                            if let selected {
                                if profiles.count == Layout.single { Text(selected.name).font(UFitTypography.title3.weight(.semibold)) }
                                if let status { account(status) }
                            }
                            if let message {
                                UFitNotice(message: message, kind: .error)
                                if selected == nil { UFitActionButton(title: Copy.retry, kind: .secondary, action: onRefresh) }
                            }
                        }
                    }.padding(Layout.spacing).frame(minHeight: viewport.size.height, alignment: profiles.isEmpty ? .center : .topLeading)
                }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func account(_ status: UFitConnectAccountStatus) -> some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            if !status.liveMode { Text(Copy.test).font(UFitTypography.caption.weight(.semibold)).padding(.horizontal, Layout.row).padding(.vertical, Layout.pillVertical).background(Color.ufitCanvas, in: Capsule()) }
            Text(status.stage.label).font(UFitTypography.title2.weight(.medium))
            if status.stage != .ready { Text(Copy.required).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            if let selectedCountry = status.country {
                VStack(alignment: .leading, spacing: Layout.row) {
                    Text(Copy.country).font(UFitTypography.subheadline.weight(.medium))
                    Text(countries.first { $0.id == selectedCountry }?.name ?? selectedCountry)
                }
            } else if status.canConfigure {
                VStack(alignment: .leading, spacing: Layout.row) {
                    Text(Copy.country).font(UFitTypography.subheadline.weight(.medium))
                    UFitSelection(Copy.country, selection: $country, options: countries.map { .init(value: $0.id, title: $0.name) })
                        .labelsHidden().pickerStyle(.menu).tint(Color.ufitInk).frame(minHeight: Layout.touch).disabled(isBusy)
                    Text(Copy.immutable).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                }
            }
            Divider()
            capability(Copy.transfers, status.transfersEnabled)
            capability(Copy.payouts, status.payoutsEnabled)
            if status.canConfigure {
                if status.stage != .ready {
                    UFitActionButton(title: Copy.start, isBusy: isBusy, disabled: status.country == nil && country.isEmpty, action: onConfigure)
                }
                if status.stage == .ready || status.stage == .restricted {
                    UFitActionButton(title: Copy.dashboard, kind: .secondary, isBusy: isBusy, action: onDashboard)
                }
            } else { Text(Copy.owner).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
        }
    }
    private func capability(_ title: String, _ enabled: Bool) -> some View {
        HStack { Text(title).font(UFitTypography.subheadline); Spacer(); Text(enabled ? Copy.enabled : Copy.pending).font(UFitTypography.subheadline.weight(.medium)) }
    }
}
