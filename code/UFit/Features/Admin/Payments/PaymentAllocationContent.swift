import SwiftUI

struct UFitPaymentAllocationContent: View {
    let store: UFitPaymentAllocationStore
    let onBack: () -> Void
    private typealias Copy = UFitPaymentAllocationCopy
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                UFitButton { Task { await store.refresh() } } label: {
                    if store.isLoading { UFitLoading() } else { UFitIcon(systemName: UFitAdminOrdersCopy.refreshIcon) }
                }.accessibilityLabel(UFitAdminOrdersCopy.refresh).disabled(store.isSending || store.isLoading)
            }.disabled(store.isSending)
            if let message = store.message {
                VStack(spacing: UFitSpace.md) {
                    UFitNotice(message: message, kind: store.messageIsError ? .error : .information)
                    if store.needsStatusRefresh || store.readFailed || store.document == nil {
                        UFitActionButton(title: store.needsStatusRefresh ? Copy.check : UFitAdminOrdersCopy.retry,
                            kind: .secondary, isBusy: store.isLoading) { Task { await store.refresh() } }
                    }
                }.padding(.horizontal, UFitSpace.page).padding(.top, UFitSpace.md).padding(.bottom, UFitSpace.sm)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xxl) {
                    if let document = store.document {
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            Text(document.context.orderNumber).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                            HStack(alignment: .top, spacing: UFitSpace.md) {
                                Text(document.context.brand.name).font(UFitTypography.callout).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: UFitSpace.sm)
                                if document.context.liveMode == false { Text(UFitPaymentSettlementCopy.test).font(UFitTypography.caption) }
                            }.foregroundStyle(Color.ufitSecondaryText)
                        }
                        if !store.needsStatusRefresh { content(document) }
                        Text(UFitPaymentSettlementCopy.consulted(document.asOf)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    } else if store.message == nil { UFitLoading(Copy.loading).frame(maxWidth: .infinity).padding(.vertical, UFitSpace.editorial) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, UFitSpace.xl)
            }.padding(.horizontal, UFitSpace.page)
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    @ViewBuilder private func content(_ document: UFitPaymentAllocationDocument) -> some View {
        switch document.state {
        case .notPrepared:
            VStack(alignment: .leading, spacing: UFitSpace.lg) {
                UFitEditorialHeading(title: Copy.prepareTitle, editorial: false)
                Text(Copy.prepareScope).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                UFitActionButton(title: Copy.prepare, isBusy: store.isSending, disabled: !store.canPrepare) { Task { await store.prepare() } }
            }
        case .blocked:
            if let reason = document.blockReason {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    UFitEditorialHeading(title: reason.title, editorial: false)
                    Text(reason.message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    UFitActionButton(title: Copy.back, kind: .secondary, action: onBack)
                }
            }
        case .recorded:
            if let plan = document.plan { recorded(plan, context: document.context) }
        }
    }
    private func recorded(_ plan: UFitPaymentAllocationPlan, context: UFitPaymentAllocationDocument.Context) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xxl) {
            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                Text(Copy.net).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                Text(UFitMoney.format(plan.netAmount, currency: plan.settlementCurrency)).font(UFitTypography.largeTitle.weight(.medium)).monospacedDigit()
                Text(Copy.scope).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            }
            UFitLabeledValue(Copy.purchase, value: UFitMoney.format(plan.presentmentAmount, currency: plan.presentmentCurrency)).font(UFitTypography.callout)
            if plan.hasDeficit { UFitNotice(message: Copy.deficit, kind: .error) }
            VStack(alignment: .leading, spacing: UFitSpace.lg) {
                if let brand = plan.lines.first(where: { $0.recipient.kind == .brand }) {
                    share(title: context.brand.name, role: Copy.brand, line: brand, currency: plan.settlementCurrency)
                }
                if let platform = plan.lines.first(where: { $0.recipient.kind == .platform }) {
                    share(title: Copy.platform, role: nil, line: platform, currency: plan.settlementCurrency)
                }
            }
            VStack(alignment: .leading, spacing: UFitSpace.lg) {
                UFitEditorialHeading(title: Copy.creators, editorial: false)
                if context.creatorItems.isEmpty { Text(Copy.emptyCreators).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                ForEach(context.creatorItems) { item in
                    if let line = plan.lines.first(where: { $0.recipient.commissionID == item.commissionId }) {
                        VStack(alignment: .leading, spacing: UFitSpace.md) {
                            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                Text(item.itemName).font(UFitTypography.headline).fixedSize(horizontal: false, vertical: true)
                                Text(item.creatorName).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                            }
                            Text(UFitMoney.format(line.netAmount, currency: plan.settlementCurrency)).font(UFitTypography.title2).monospacedDigit()
                            UFitLabeledValue(Copy.original, value: UFitMoney.format(line.presentmentAmount, currency: plan.presentmentCurrency)).font(UFitTypography.caption)
                        }.padding(UFitSpace.lg).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
                    }
                }
            }
            VStack(alignment: .leading, spacing: UFitSpace.md) {
                UFitLabeledValue(Copy.totalFees, value: UFitMoney.format(plan.feeAmount, currency: plan.settlementCurrency)).font(UFitTypography.callout)
                UFitLabeledValue(Copy.preparedAt, value: plan.createdAt.label).font(UFitTypography.caption)
            }
            UFitDisclosure(Copy.references) {
                VStack(alignment: .leading, spacing: UFitSpace.md) {
                    reference(Copy.terms, value: plan.policyId)
                    reference(UFitPaymentSettlementCopy.charge, value: plan.chargeId)
                    reference(UFitPaymentSettlementCopy.transaction, value: plan.balanceTransactionId)
                }
            }
        }
    }
    private func share(title: String, role: String?, line: UFitPaymentAllocationPlan.Line, currency: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            if let role { Text(role).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
            HStack(alignment: .firstTextBaseline, spacing: UFitSpace.md) {
                Text(title).font(UFitTypography.headline).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: UFitSpace.sm)
                Text(UFitMoney.format(line.netAmount, currency: currency)).font(UFitTypography.title3).monospacedDigit()
            }
            if line.feeAmount > .zero {
                UFitLabeledValue(Copy.gross, value: UFitMoney.format(line.grossAmount, currency: currency)).font(UFitTypography.caption)
                UFitLabeledValue(Copy.fee, value: UFitMoney.format(line.feeAmount, currency: currency)).font(UFitTypography.caption)
            }
            Divider()
        }
    }
    private func reference(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xxs) {
            Text(title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            Text(value).font(UFitTypography.callout.monospaced()).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}
