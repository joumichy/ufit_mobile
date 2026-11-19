import SwiftUI

struct UFitPublicationCalendarHost: View {
    @Bindable var store: UFitPublicationCalendarStore
    let onBack: () -> Void
    let onOpen: (UFitManagedOutfitStore) -> Void
    private enum Copy {
        static let title = String(localized: "Calendrier")
        static let subtitle = String(localized: "Les publications de votre espace.")
        static let space = " "
        static let zone = String(localized: "Dates affichées dans le fuseau")
        static let empty = String(localized: "Aucune publication prévue ce jour.")
        static let guidance = String(localized: "Ouvrez une tenue depuis vos publications pour la programmer.")
        static let incomplete = String(localized: "Calendrier incomplet : les repères et les publications du jour couvrent uniquement les tenues déjà chargées.")
        static let partialDay = String(localized: "Aucune publication parmi les tenues chargées pour ce jour. Chargez la suite du mois pour vérifier.")
        static let more = String(localized: "Charger la suite du mois")
        static let refresh = String(localized: "Actualiser le calendrier")
        static let retry = String(localized: "Réessayer")
        static let loading = String(localized: "Chargement du calendrier")
        static let overdue = String(localized: "Publication en attente. Vérifiez le profil et la disponibilité des pièces si le retard persiste.")
    }
    private enum Icon { static let next = "chevron.right" }
    private enum Layout { static let imageWidth: CGFloat = 60; static let imageHeight: CGFloat = 78 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    VStack(alignment: .leading, spacing: UFitSpace.sm) {
                        Text(Copy.title).ufitFont(size: UFitTypography.Size.editorial, design: .serif).accessibilityAddTraits(.isHeader)
                        Text(Copy.subtitle).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    }
                    UFitPublicationMonthGrid(month: store.month, selectedDay: store.selectedDay, timeZone: store.timeZone,
                        markedDays: store.markedDays, isEnabled: store.canRead, onMoveMonth: { value in Task { await store.moveMonth(value) } }, onSelectDay: { store.selectedDay = $0 })
                    if store.canRead && store.nextCursor != nil { Text(Copy.incomplete).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    Text(Copy.zone + Copy.space + store.timeZone.identifier).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    Divider()
                    Text(UFitPublicationFormatting.text(store.selectedDay, template: .day, zone: store.timeZone))
                        .font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                    if let message = store.message {
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            UFitFieldError(message: message)
                            UFitActionButton(title: Copy.retry, kind: .secondary) { Task { if let detail = await store.retry() { onOpen(detail) } } }
                        }
                    }
                    if store.isLoading { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    else if store.hasLoaded && store.message == nil && store.selectedOutfits.isEmpty {
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            Text(store.nextCursor == nil ? Copy.empty : Copy.partialDay).font(UFitTypography.headline)
                            Text(Copy.guidance).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        }
                    }
                    if !store.isLoading {
                        LazyVStack(spacing: UFitSpace.lg) {
                            ForEach(store.selectedOutfits) { outfit in
                                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                    entry(outfit)
                                    Divider()
                                }
                            }
                        }
                    }
                    if store.canRead && store.nextCursor != nil {
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            if store.isLoadingMore { UFitLoading().frame(maxWidth: .infinity) }
                            else { UFitActionButton(title: Copy.more, kind: .secondary) { Task { await store.load(more: true) } } }
                        }
                    }
                }.padding(UFitSpace.xl)
            }.ufitRefreshable(isEnabled: !store.isLoading && !store.isLoadingMore && store.canRead, title: Copy.refresh) { await store.load() }
        }.background(Color.ufitCanvas).foregroundStyle(Color.ufitInk)
            .task { await store.load() }.onDisappear { store.cancel() }
    }
    private func entry(_ outfit: UFitManagedOutfit) -> some View {
        UFitButton {
            Task { if let detail = await store.open(outfit.id) { onOpen(detail) } }
        } label: {
            HStack(spacing: UFitSpace.md) {
                if let source = outfit.images.first?.displayUrl {
                    FashionImage(source: source).frame(width: Layout.imageWidth, height: Layout.imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: UFitRadius.field))
                }
                VStack(alignment: .leading, spacing: UFitSpace.xs) {
                    Text(outfit.status.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    Text(outfit.title).font(UFitTypography.headline)
                    if let date = outfit.scheduledFor.flatMap(UFitPublicationDate.parse) {
                        Text(UFitPublicationFormatting.text(date, template: .time, zone: store.timeZone)).font(UFitTypography.callout)
                        if date < Date() && outfit.status == .scheduled {
                            Text(Copy.overdue).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        }
                    }
                }.multilineTextAlignment(.leading)
                Spacer(minLength: UFitSpace.xs)
                if store.busyIDs.contains(outfit.id) { UFitLoading() }
                else { UFitIcon(systemName: Icon.next).font(UFitTypography.caption) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.ufitButtonStyle(.text).disabled(store.busyIDs.contains(outfit.id))
    }
}
