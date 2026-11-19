import SwiftUI

struct UFitNotificationPreferencesContent: View {
    @Binding var choices: UFitNotificationChoices
    let hasLoaded: Bool
    let hasChanges: Bool
    let isLoading: Bool
    let isSaving: Bool
    let requiresReload: Bool
    let allowsEditing: Bool
    let comparison: UFitNotificationChoices?
    let disablesChannel: Bool
    let message: String?
    let messageKind: UFitNoticeKind
    let onBack: () -> Void
    let onReload: () -> Void
    let onSave: () -> Void
    var devicePermission: UFitNotificationPermission? = nil
    var devicePhase = UFitNotificationDevicePhase.idle
    var deviceBusy = false
    var deviceMessage: String? = nil
    var onDeviceAction: (() -> Void)? = nil
    @State private var confirmingDiscard = false
    private typealias Copy = UFitNotificationPreferencesCopy
    private var busy: Bool { isLoading || isSaving }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }) {
                if hasLoaded && !requiresReload {
                    if isLoading { UFitLoading().frame(width: UFitControlSize.touch, height: UFitControlSize.touch) }
                }
            }.disabled(isSaving)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    if hasLoaded {
                        Text(Copy.introduction).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        channel(Copy.email, detail: Copy.emailDetail, isOn: $choices.emailEnabled)
                        Divider()
                        channel(Copy.push, detail: Copy.pushDetail, isOn: $choices.pushEnabled)
                        if let devicePermission, let onDeviceAction {
                            Divider()
                            UFitNotificationDeviceContent(permission: devicePermission, phase: devicePhase, isBusy: deviceBusy,
                                message: deviceMessage, onAction: onDeviceAction)
                        }
                        if let comparison, comparison != choices {
                            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                Text(Copy.current).font(UFitTypography.headline)
                                UFitLabeledValue(Copy.email) { Text(comparison.emailEnabled ? Copy.enabled : Copy.disabled) }
                                UFitLabeledValue(Copy.push) { Text(comparison.pushEnabled ? Copy.enabled : Copy.disabled) }
                            }
                        }
                        if !allowsEditing { UFitNotice(message: Copy.readOnly) }
                        else if disablesChannel { Text(Copy.inProgress).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                        if let message { UFitNotice(message: message, kind: messageKind) }
                    } else if isLoading || message == nil {
                        UFitLoading(Copy.loading).frame(maxWidth: .infinity)
                    } else {
                        UFitEmptyState(title: Copy.unavailable, message: message, symbol: Copy.bell, actionTitle: Copy.retry, action: onReload)
                    }
                }.padding(UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !busy, title: Copy.refresh) { onReload() }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if hasLoaded && allowsEditing {
                UFitActionButton(title: requiresReload ? Copy.refresh : Copy.save, isBusy: busy,
                    disabled: !requiresReload && !hasChanges, action: requiresReload ? onReload : onSave)
                    .padding(UFitSpace.md).background(Color.ufitCanvas).overlay(alignment: .top) { Divider() }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(Copy.leave, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                UFitButton(Copy.discard, role: .destructive, action: onBack)
                UFitButton(Copy.keep, role: .cancel) {}
            } message: { Text(Copy.leaveDetail) }
    }
    private func channel(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            UFitToggle(title, isOn: isOn).disabled(busy || !allowsEditing)
            Text(detail).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
        }
    }
}
