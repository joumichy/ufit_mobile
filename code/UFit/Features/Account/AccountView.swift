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
    var onStyles: (() -> Void)?
    var onShippingAddresses: (() -> Void)?
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
        static let shipping = String(localized: "Mes adresses")
        static let shippingIcon = "mappin.and.ellipse"
        static let purchases = String(localized: "Mes achats")
        static let preferences = String(localized: "Préférences")
        static let spaces = String(localized: "Mes espaces")
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
                if onBack == nil { Text(Copy.title).ufitFont(size: Layout.title, weight: .regular, design: .serif).accessibilityAddTraits(.isHeader) }
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
                        UFitActionButton(title: Copy.cancel, kind: .secondary, disabled: isBusy) { editing = false }
                    }
                } else {
                    UFitButton(Copy.edit) { editedName = name; editing = true }.ufitButtonStyle(.secondary, compact: true).disabled(isBusy)
                }
                if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                if onOrders != nil || onShippingAddresses != nil {
                    section(Copy.purchases) {
                        if let onOrders { UFitExperienceActionRow(title: Copy.orders, systemImage: Copy.ordersIcon, action: onOrders) }
                        if onOrders != nil && onShippingAddresses != nil { Divider() }
                        if let onShippingAddresses { UFitExperienceActionRow(title: Copy.shipping, systemImage: Copy.shippingIcon, action: onShippingAddresses) }
                    }
                }
                if onNotifications != nil || onStyles != nil {
                    section(Copy.preferences) {
                        if let onNotifications { UFitExperienceActionRow(title: UFitNotificationPreferencesCopy.title, systemImage: Copy.notificationsIcon, action: onNotifications) }
                        if onNotifications != nil && onStyles != nil { Divider() }
                        if let onStyles { UFitExperienceActionRow(title: UFitStylePreferencesCopy.title, systemImage: UFitStylePreferencesCopy.icon, action: onStyles) }
                    }
                }
                if onApplications != nil || onChooseExperience != nil {
                    section(Copy.spaces) {
                        if let onApplications { UFitExperienceActionRow(title: Copy.applications, systemImage: Copy.applicationsIcon, action: onApplications) }
                        if onApplications != nil && onChooseExperience != nil { Divider() }
                        if let onChooseExperience { UFitExperienceActionRow(title: Copy.choose, systemImage: Copy.chooseIcon, action: onChooseExperience) }
                    }
                }
                Divider()
                UFitActionButton(title: Copy.signOut, kind: .secondary, disabled: isBusy, action: onSignOut)
                if let onDeleteAccount {
                    Divider()
                    UFitActionButton(title: UFitAccountDeletionCopy.title, kind: .secondary, role: .destructive, disabled: isBusy, action: onDeleteAccount)
                }
            }
            .padding(Layout.spacing)
            .padding(.bottom, UFitSpace.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }.clipped()
        }
        .foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
        .ufitButtonStyle(.text)
        .onChange(of: name) { _, _ in editing = false }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            Text(title).font(UFitTypography.subheadline.weight(.medium)).foregroundStyle(Color.ufitSecondaryText)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: .zero, content: content)
        }
    }
}
