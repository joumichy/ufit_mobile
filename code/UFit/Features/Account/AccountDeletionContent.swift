import SwiftUI

struct UFitAccountDeletionContent: View {
    let store: UFitAccountDeletionStore
    let onClose: () -> Void
    private typealias Copy = UFitAccountDeletionCopy
    private var title: String {
        if store.isSending { return Copy.sendingTitle }
        if store.isCompleted { return Copy.completed }
        if store.receipt != nil { return Copy.pending }
        return store.hasRequest ? Copy.uncertain : Copy.reviewTitle
    }
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: Copy.title, onClose: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    UFitIcon(systemName: store.isCompleted ? Copy.successIcon : store.receipt != nil ? Copy.pendingIcon : Copy.icon)
                        .font(UFitTypography.title).accessibilityHidden(true)
                    Text(title).font(UFitTypography.editorialTitle).accessibilityAddTraits(.isHeader)
                    if store.isSending {
                        Text(Copy.sendingDetail).font(UFitTypography.body)
                    } else if store.receipt != nil {
                        Text(store.isCompleted ? Copy.completedDetail : Copy.pendingDetail).font(UFitTypography.body)
                    } else if store.hasRequest {
                        if store.canResubmit { Text(Copy.introduction).font(UFitTypography.body) }
                        else if store.message == nil { Text(Copy.uncertainDetail).font(UFitTypography.body) }
                    } else {
                        Text(Copy.introduction).font(UFitTypography.body)
                        VStack(alignment: .leading, spacing: UFitSpace.md) {
                            Text(Copy.personal)
                            Text(Copy.orders)
                            if store.showsBrandConsequences { Text(Copy.brands) }
                        }.font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    }
                    if let message = store.message { UFitNotice(message: message, kind: store.canResubmit ? .information : .error) }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: UFitSpace.xs) {
                if store.isSending {
                    UFitActionButton(title: Copy.sending, kind: .destructive, isBusy: true) {}
                    UFitButton(Copy.close, action: onClose).ufitButtonStyle(.text)
                } else if store.isCompleted {
                    UFitActionButton(title: Copy.done, disabled: store.isBusy) { if store.finish() { onClose() } }
                } else if store.receipt != nil || store.hasRequest {
                    if store.canResubmit {
                        UFitActionButton(title: Copy.retry, kind: .destructive, disabled: !store.canConfirm) { Task { await store.confirm() } }
                    }
                    UFitActionButton(title: Copy.refresh, kind: store.canResubmit ? .secondary : .primary, isBusy: store.isBusy) { Task { await store.refresh() } }
                    UFitButton(Copy.browse, action: onClose).ufitButtonStyle(.text)
                } else {
                    UFitActionButton(title: Copy.confirm, kind: .destructive, isBusy: store.isSending, disabled: !store.canConfirm) { Task { await store.confirm() } }
                    UFitButton(Copy.cancel, action: onClose).ufitButtonStyle(.text)
                }
            }.padding(UFitSpace.page).background(Color.ufitCanvas).overlay(alignment: .top) { Divider() }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task(id: store.receipt?.phase) {
                while !Task.isCancelled, store.receipt != nil, !store.isCompleted {
                    do { try await Task.sleep(for: UFitAccountDeletionHTTP.polling) } catch { return }
                    await store.refresh()
                }
            }
    }
}
