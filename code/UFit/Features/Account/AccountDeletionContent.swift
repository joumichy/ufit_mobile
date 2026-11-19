import SwiftUI

struct UFitAccountDeletionContent: View {
    let store: UFitAccountDeletionStore
    let onClose: () -> Void
    private typealias Copy = UFitAccountDeletionCopy
    var body: some View {
        UFitContentSizedSheet {
            VStack(spacing: UFitSpace.lg) {
                UFitSheetHeader(title: Copy.reviewTitle, onClose: onClose).disabled(store.isBusy)
                VStack(alignment: .leading, spacing: UFitSpace.md) {
                    Text(Copy.introduction).font(UFitTypography.body)
                    Text(Copy.orders).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    if store.showsCreatorConsequences {
                        Text(Copy.creator).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    }
                    if store.showsBrandConsequences {
                        Text(Copy.brands).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    }
                    if let message = store.message { UFitNotice(message: message, kind: .error) }
                }.padding(.horizontal, UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: UFitSpace.xs) {
                    UFitActionButton(title: store.isBusy ? Copy.sending : Copy.confirm, kind: .destructive,
                        isBusy: store.isBusy, disabled: !store.canConfirm) {
                        Task { if await store.confirm() { onClose() } }
                    }
                    UFitActionButton(title: Copy.cancel, kind: .secondary, disabled: store.isBusy, action: onClose)
                }.padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.page)
            }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
        }.interactiveDismissDisabled(store.isBusy)
    }
}
