import SwiftUI

struct UFitPaymentSettlementContent: View {
    let document: UFitPaymentSettlementDocument?
    let isLoading: Bool; let isSending: Bool; let message: String?; let needsStatusRefresh: Bool
    let onBack: () -> Void; let onRefresh: () -> Void; let onSynchronize: () -> Void
    var onAllocation: (() -> Void)? = nil
    var onDisbursements: (() -> Void)? = nil
    private typealias Copy = UFitPaymentSettlementCopy
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isLoading { UFitLoading() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xxl) {
                    if let message { UFitNotice(message: message, kind: .error) }
                    if let document {
                        payment(document.payment)
                        if needsStatusRefresh {
                            UFitActionButton(title: Copy.refreshStatus, kind: .secondary, isBusy: isLoading, action: onRefresh)
                        } else { settlement(document) }
                        if let onAllocation {
                            UFitExperienceActionRow(title: UFitPaymentAllocationCopy.title, systemImage: UFitPaymentAllocationCopy.icon, action: onAllocation)
                                .disabled(isLoading || isSending || needsStatusRefresh)
                        }
                        if document.receipt != nil, let onDisbursements {
                            UFitExperienceActionRow(title: UFitPaymentDisbursementCopy.title, systemImage: UFitPaymentDisbursementCopy.icon, action: onDisbursements)
                                .disabled(isLoading || isSending || needsStatusRefresh)
                        }
                        references(document)
                        Text(Copy.consulted(document.asOf)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    } else if message != nil {
                        UFitActionButton(title: UFitAdminOrdersCopy.retry, kind: .secondary, isBusy: isLoading, action: onRefresh)
                    } else {
                        UFitLoading(Copy.loading).frame(maxWidth: .infinity).padding(.vertical, UFitSpace.editorial)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, UFitSpace.xl)
            }.padding(.horizontal, UFitSpace.page)
                .ufitRefreshable(isEnabled: !isLoading && !isSending, title: UFitAdminOrdersCopy.refresh) { onRefresh() }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func payment(_ payment: UFitPaymentSettlementDocument.Payment) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            Text(payment.orderNumber).font(UFitTypography.title2).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(payment.status.label).font(UFitTypography.subheadline.weight(.medium))
            HStack(alignment: .firstTextBaseline) {
                Text(Copy.customerAmount).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                Spacer(minLength: UFitSpace.sm)
                Text(UFitMoney.format(payment.amount, currency: payment.currency)).font(UFitTypography.headline)
            }.accessibilityElement(children: .combine)
            Text(payment.createdAt.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
        }
    }
    @ViewBuilder private func settlement(_ document: UFitPaymentSettlementDocument) -> some View {
        switch document.state {
        case .recorded:
            if let receipt = document.receipt { recorded(receipt) }
        case .notRequested:
            VStack(spacing: UFitSpace.lg) {
                UFitEmptyState(title: Copy.notRequested, symbol: Copy.lookup)
                synchronizeButton(Copy.verify)
            }
        case .queued, .processing:
            VStack(alignment: .leading, spacing: UFitSpace.lg) {
                UFitLoading(Copy.checking).frame(maxWidth: .infinity).padding(.vertical, UFitSpace.lg)
                if let failure = document.failureCode {
                    UFitNotice(message: failure.label, kind: .information)
                    if let next = document.nextAttemptAt { Text(Copy.retryAt(next)).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    synchronizeButton(Copy.retry)
                }
            }
        case .needsReview:
            VStack(alignment: .leading, spacing: UFitSpace.lg) {
                UFitEditorialHeading(title: Copy.review, editorial: false)
                if let failure = document.failureCode { UFitNotice(message: failure.label, kind: .error) }
                synchronizeButton(Copy.retry)
            }
        }
    }
    private func synchronizeButton(_ title: String) -> some View {
        UFitActionButton(title: title, kind: .secondary, isBusy: isSending, disabled: isLoading, action: onSynchronize)
    }
    private func recorded(_ receipt: UFitPaymentSettlementDocument.Receipt) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xl) {
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text(Copy.initial).font(UFitTypography.title3).accessibilityAddTraits(.isHeader)
                Spacer(minLength: UFitSpace.sm)
                if !receipt.liveMode { Text(Copy.test).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
            }
            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                Text(Copy.net).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                Text(UFitMoney.format(receipt.netAmount, currency: receipt.settlementCurrency))
                    .font(UFitTypography.largeTitle.weight(.medium)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
                Text(Copy.initialScope).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            }.accessibilityElement(children: .combine)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: UFitSpace.xl) { amount(Copy.gross, value: receipt.settlementAmount, currency: receipt.settlementCurrency); Spacer(); amount(Copy.fees, value: receipt.feeAmount, currency: receipt.settlementCurrency) }
                VStack(alignment: .leading, spacing: UFitSpace.lg) { amount(Copy.gross, value: receipt.settlementAmount, currency: receipt.settlementCurrency); amount(Copy.fees, value: receipt.feeAmount, currency: receipt.settlementCurrency) }
            }
            if receipt.chargeCurrency != receipt.settlementCurrency {
                Text(Copy.conversion).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            }
            Divider()
        }
    }
    private func amount(_ title: String, value: Int, currency: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            Text(title).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            Text(UFitMoney.format(value, currency: currency)).font(UFitTypography.title3).monospacedDigit()
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
    private func references(_ document: UFitPaymentSettlementDocument) -> some View {
        UFitDisclosure(Copy.references) {
            VStack(alignment: .leading, spacing: UFitSpace.md) {
                reference(Copy.paymentIntent, value: document.payment.providerPaymentIntentId)
                if let receipt = document.receipt {
                    reference(Copy.charge, value: receipt.chargeId)
                    reference(Copy.transaction, value: receipt.balanceTransactionId)
                    UFitLabeledValue(Copy.recorded, value: receipt.recordedAt.label).font(UFitTypography.caption)
                }
            }
        }
    }
    private func reference(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xxs) {
            Text(title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            Text(value).font(UFitTypography.callout.monospaced()).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}
