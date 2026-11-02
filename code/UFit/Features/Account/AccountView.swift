import SwiftUI

struct UFitAccountView: View {
    let name: String
    let email: String
    let isBusy: Bool
    let message: String?
    let onSaveName: (String) -> Void
    let onSignOut: () -> Void
    var onOrders: (() -> Void)?
    var onApplications: (() -> Void)?
    var onChooseExperience: (() -> Void)?
    var onNotifications: (() -> Void)?
    var onDeleteAccount: (() -> Void)?
    var onBack: (() -> Void)?
    var photoHeader: AnyView? = nil
    @State private var editing = false
    @State private var editedName = String()
    private enum Copy {
        static let applications = String(localized: "Mes candidatures")
        static let applicationsIcon = "doc.text"
        static let choose = String(localized: "Changer d’espace")
        static let chooseIcon = "arrow.triangle.swap"
        static let orders = String(localized: "Mes commandes")
        static let ordersIcon = "bag"
        static let notificationsIcon = "bell"
        static let title = String(localized: "Mon compte")
        static let edit = String(localized: "Modifier mon profil")
        static let name = String(localized: "Nom affiché")
        static let save = String(localized: "Enregistrer")
        static let cancel = String(localized: "Annuler")
        static let signOut = String(localized: "Se déconnecter")
        static let person = "person.crop.circle"
        static let editIcon = "pencil"
        static let exitIcon = "rectangle.portrait.and.arrow.right"
    }
    private enum Layout {
        static let spacing: CGFloat = UFitSpace.xl
        static let portrait: CGFloat = 64
        static let title: CGFloat = UFitTypography.Size.editorial
        static let radius: CGFloat = UFitRadius.action
        static let bottom: CGFloat = 100
        static let touch: CGFloat = UFitControlSize.touch
    }
    var body: some View {
        VStack(spacing: .zero) {
            if let onBack { DetailHeader(title: Copy.title, onBack: onBack) }
            ScrollView {
            VStack(alignment: .leading, spacing: Layout.spacing) {
                if onBack == nil { Text(Copy.title).ufitFont(size: Layout.title, weight: .regular, design: .serif) }
                if let photoHeader { photoHeader }
                else { HStack(spacing: Layout.spacing) {
                    UFitIcon(systemName: Copy.person).ufitFont(size: Layout.portrait, weight: .ultraLight)
                    VStack(alignment: .leading) {
                        if !name.isEmpty { Text(name).font(UFitTypography.title3.weight(.semibold)) }
                        Text(email).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                    }
                }
                }
                if editing {
                    VStack(alignment: .leading, spacing: Layout.spacing) {
                        UFitTextField(label: Copy.name, text: $editedName, contentType: .name)
                        UFitActionButton(title: Copy.save, isBusy: isBusy, disabled: editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editedName == name, action: { onSaveName(editedName) })
                        UFitButton(Copy.cancel) { editing = false }.disabled(isBusy)
                    }
                } else {
                    UFitButton { editedName = name; editing = true } label: { Label(Copy.edit, systemImage: Copy.editIcon) }
                }
                if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                Divider()
                if let onOrders { UFitButton(action: onOrders) { Label(Copy.orders, systemImage: Copy.ordersIcon) }.frame(minHeight: Layout.touch) }
                if let onApplications { UFitButton(action: onApplications) { Label(Copy.applications, systemImage: Copy.applicationsIcon) }.frame(minHeight: Layout.touch) }
                if let onNotifications { UFitButton(action: onNotifications) { Label(UFitNotificationPreferencesCopy.title, systemImage: Copy.notificationsIcon) }.frame(minHeight: Layout.touch) }
                if let onChooseExperience { UFitButton(action: onChooseExperience) { Label(Copy.choose, systemImage: Copy.chooseIcon) }.frame(minHeight: Layout.touch) }
                UFitButton(action: onSignOut) { Label(Copy.signOut, systemImage: Copy.exitIcon) }.disabled(isBusy)
                if let onDeleteAccount {
                    Divider()
                    UFitButton(UFitAccountDeletionCopy.title, role: .destructive, action: onDeleteAccount).disabled(isBusy)
                }
            }
            .padding(Layout.spacing)
            .padding(.bottom, UFitSpace.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        }
        .foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
        .ufitButtonStyle(.text)
        .onChange(of: name) { _, _ in editing = false }
    }
}
