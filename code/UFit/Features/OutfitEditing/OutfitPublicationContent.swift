import SwiftUI

struct UFitOutfitPublicationHost: View {
    @Bindable var store: UFitOutfitPublicationStore
    let onClose: () -> Void
    @State private var confirmingCancellation = false
    @State private var confirmingDiscard = false
    private enum Copy {
        static let title = String(localized: "Programmation")
        static let context = String(localized: "VOTRE PUBLICATION")
        static let time = String(localized: "Heure locale · 24 h")
        static let privacy = String(localized: "La tenue restera privée jusqu’à la date choisie.")
        static let schedule = String(localized: "Programmer la publication")
        static let save = String(localized: "Enregistrer la date")
        static let cancel = String(localized: "Annuler la programmation")
        static let cancellation = String(localized: "La tenue reviendra dans les brouillons.")
        static let cancellationTitle = String(localized: "Annuler la programmation ?")
        static let keep = String(localized: "Garder la programmation")
        static let incomplete = String(localized: "Choisissez une date et une heure.")
        static let invalid = String(localized: "Cette heure n’existe pas dans le fuseau choisi.")
        static let discardTitle = String(localized: "Abandonner ces changements ?")
        static let discard = String(localized: "Abandonner")
        static let continueEditing = String(localized: "Continuer la saisie")
        static let discardMessage = String(localized: "La date enregistrée restera inchangée.")
    }
    private enum Layout {
        static let coverWidth: CGFloat = 60
        static let coverHeight: CGFloat = 80
        static let tracking: CGFloat = 1.4
        static let titleLines = 2
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: {
                if store.hasChanges { confirmingDiscard = true } else { onClose() }
            }).disabled(store.isSaving)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xxl) {
                    context
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        Text(Copy.time).font(UFitTypography.subheadline.weight(.medium))
                        UFitTimeEntry(hours: $store.hourText, minutes: $store.minuteText)
                        UFitTimeZoneChoice(identifier: store.timeZoneID, date: store.date ?? store.day, onSelect: store.changeZone)
                    }
                    UFitPublicationMonthGrid(month: store.month, selectedDay: store.day, timeZone: store.zone,
                        isEnabled: !store.isSaving, onMoveMonth: store.moveMonth, onSelectDay: { store.day = $0 })
                    if store.outfit.document.scheduledFor != nil {
                        UFitActionButton(title: Copy.cancel, kind: .secondary, role: .destructive,
                            disabled: store.isSaving, action: { confirmingCancellation = true })
                    }
                }.padding(UFitSpace.page)
            }.scrollDismissesKeyboard(.interactively).disabled(store.isSaving)
        }.safeAreaInset(edge: .bottom, spacing: .zero) { saveBar }
            .background(Color.ufitCanvas).foregroundStyle(Color.ufitInk)
            .environment(\.ufitPrimarySection, false).interactiveDismissDisabled(store.isSaving || store.hasChanges)
            .onChange(of: store.hasSaved) { _, saved in if saved { onClose() } }
            .ufitConfirmationDialog(Copy.cancellationTitle, isPresented: $confirmingCancellation, titleVisibility: .visible) {
                UFitButton(Copy.cancel, role: .destructive) { Task { await store.save(cancel: true) } }
                UFitButton(Copy.keep, role: .cancel) {}
            } message: { Text(Copy.cancellation) }
            .ufitConfirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                UFitButton(Copy.discard, role: .destructive, action: onClose)
                UFitButton(Copy.continueEditing, role: .cancel) {}
            } message: { Text(Copy.discardMessage) }
    }
    private var context: some View {
        HStack(alignment: .center, spacing: UFitSpace.md) {
            if let source = store.outfit.document.images.first?.displayUrl {
                FashionImage(source: source).frame(width: Layout.coverWidth, height: Layout.coverHeight)
                    .clipped().clipShape(RoundedRectangle(cornerRadius: UFitRadius.small)).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                Text(Copy.context).font(UFitTypography.caption).tracking(Layout.tracking).foregroundStyle(Color.ufitSecondaryText)
                Text(store.outfit.document.title).ufitFont(size: UFitTypography.Size.title, design: .serif)
                    .lineLimit(Layout.titleLines).fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(store.outfit.document.title)
            }
            Spacer(minLength: .zero)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var saveBar: some View {
        VStack(alignment: .leading, spacing: UFitSpace.sm) {
            if let date = store.date {
                Text(UFitPublicationFormatting.text(date, template: .time, zone: store.zone))
                    .font(UFitTypography.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            } else if store.message == nil {
                Text(store.hasValidTime ? Copy.invalid : Copy.incomplete).font(UFitTypography.callout)
                    .foregroundStyle(store.hasValidTime ? Color.ufitDanger : Color.ufitSecondaryText)
            }
            Text(Copy.privacy).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            if let message = store.message { UFitFieldError(message: message) }
            UFitActionButton(title: store.outfit.document.status == .scheduled ? Copy.save : Copy.schedule,
                isBusy: store.isSaving, action: { Task { await store.save() } })
        }.padding(.horizontal, UFitSpace.page).padding(.vertical, UFitSpace.md).background(Color.ufitCanvas)
            .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
    }
}
