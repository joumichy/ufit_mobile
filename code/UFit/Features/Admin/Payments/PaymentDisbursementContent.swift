import SwiftUI

struct UFitPaymentDisbursementContent: View {
    let store: UFitPaymentDisbursementStore
    let onBack: () -> Void; let onAllocation: () -> Void
    private typealias Copy = UFitPaymentDisbursementCopy
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                UFitButton { Task { await store.refresh() } } label: {
                    if store.isLoading { UFitLoading() } else { UFitIcon(systemName: UFitAdminOrdersCopy.refreshIcon) }
                }.accessibilityLabel(Copy.check).disabled(store.isSending || store.isLoading)
            }.disabled(store.isSending)
            if let message = store.message {
                VStack(spacing: UFitSpace.md) {
                    UFitNotice(message: message, kind: .error)
                    UFitActionButton(title: store.needsStatusRefresh ? Copy.check : UFitAdminOrdersCopy.retry,
                        kind: .secondary, isBusy: store.isLoading) { Task { await store.refresh() } }
                }.padding(.horizontal, UFitSpace.page).padding(.vertical, UFitSpace.md)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xxl) {
                    if let document = store.document {
                        context(document)
                        if store.readFailed { Text(Copy.previous).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                        if !store.needsStatusRefresh { status(document) }
                        if document.operations.contains(where: { $0.receipt != nil }), let receipt = store.reference.receipt { cash(document, currency: receipt.settlementCurrency) }
                        if let targets = document.targets {
                            UFitPaymentDisbursementTargetsView(targets: targets, context: document.allocation.context,
                                reserved: document.assessment?.isReservation == true, calculatedAt: document.assessmentRecordedAt)
                        }
                        if document.operations.isEmpty {
                            if document.allocation.state != .blocked {
                                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                    Text(Copy.noOperations).font(UFitTypography.headline)
                                    Text(Copy.noOperationsScope).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                                }
                            }
                        } else { operations(document) }
                        if document.allocation.state != .blocked {
                            UFitExperienceActionRow(title: Copy.initial, systemImage: UFitPaymentAllocationCopy.icon, action: onAllocation).disabled(store.isSending)
                        }
                        Text(UFitPaymentSettlementCopy.consulted(document.asOf)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    } else if store.message == nil {
                        UFitLoading(Copy.loading).frame(maxWidth: .infinity).padding(.vertical, UFitSpace.editorial)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, UFitSpace.xl)
            }.padding(.horizontal, UFitSpace.page)
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func context(_ document: UFitPaymentDisbursementDocument) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.sm) {
            Text(document.allocation.context.orderNumber).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: UFitSpace.md) {
                Text(document.allocation.context.brand.name).font(UFitTypography.callout).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: UFitSpace.sm)
                if document.allocation.context.liveMode == false { Text(UFitPaymentSettlementCopy.test).font(UFitTypography.caption) }
            }.foregroundStyle(Color.ufitSecondaryText)
            UFitLabeledValue(Copy.purchase, value: UFitMoney.format(store.reference.payment.amount, currency: store.reference.payment.currency)).font(UFitTypography.caption)
        }
    }
    @ViewBuilder private func status(_ document: UFitPaymentDisbursementDocument) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            if let reason = document.allocation.blockReason {
                UFitEditorialHeading(title: reason.title, editorial: false)
                Text(reason.message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            } else if document.state == .queued || document.state == .processing {
                HStack(spacing: UFitSpace.md) { UFitLoading(); Text(Copy.processing).font(UFitTypography.title3) }
                Text(Copy.processingScope).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            } else if document.awaitsConfirmation {
                UFitEditorialHeading(title: UFitPaymentDisbursementReason.creationUnconfirmed.title, editorial: false)
                Text(UFitPaymentDisbursementReason.creationUnconfirmed.message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            } else if document.hasDeficit {
                UFitEditorialHeading(title: Copy.deficit, editorial: false)
                Text(Copy.deficitScope).font(UFitTypography.callout).foregroundStyle(Color.ufitDanger)
            } else if let reason = document.reason {
                UFitEditorialHeading(title: reason.title, editorial: false)
                Text(reason.message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            } else {
                UFitEditorialHeading(title: Copy.notRequested, editorial: false)
                Text(Copy.notRequestedScope).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            }
            if store.canResume || store.isSending {
                UFitActionButton(title: document.state == .notRequested ? Copy.verify : Copy.resume, kind: .secondary,
                    isBusy: store.isSending, disabled: !store.canResume) { Task { await store.resume() } }
            }
        }
    }
    private func cash(_ document: UFitPaymentDisbursementDocument, currency: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                Text(Copy.net).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                Text(UFitMoney.format(document.netTransferred, currency: currency))
                    .font(UFitTypography.largeTitle.weight(.medium)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            }.accessibilityElement(children: .combine)
            Text(Copy.transferScope).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: UFitSpace.xl) { cashAmount(Copy.transferred, amount: document.transferred, currency: currency); Spacer(); cashAmount(Copy.recovered, amount: document.recovered, currency: currency) }
                VStack(alignment: .leading, spacing: UFitSpace.lg) { cashAmount(Copy.transferred, amount: document.transferred, currency: currency); cashAmount(Copy.recovered, amount: document.recovered, currency: currency) }
            }
        }.padding(UFitSpace.lg).frame(maxWidth: .infinity, alignment: .leading).background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
    }
    private func cashAmount(_ title: String, amount: Int, currency: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            Text(title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            Text(UFitMoney.format(amount, currency: currency)).font(UFitTypography.headline).monospacedDigit()
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
    private func operations(_ document: UFitPaymentDisbursementDocument) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
            UFitEditorialHeading(title: Copy.history, editorial: false)
            ForEach(document.operations) { operation in
                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: UFitSpace.md) {
                        Text(operation.kind == .transfer ? Copy.transfer : Copy.reversal).font(UFitTypography.headline)
                        Spacer(minLength: UFitSpace.sm)
                        Text(UFitMoney.format(operation.kind == .transfer ? operation.amount : .zero - operation.amount, currency: operation.currency)).font(UFitTypography.headline).monospacedDigit()
                    }
                    beneficiary(operation, document: document)
                    Text(operationStatus(operation)).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    if let receipt = operation.receipt {
                        UFitLabeledValue(Copy.recordedAt, value: Copy.date(receipt.recordedAt)).font(UFitTypography.caption)
                    } else { UFitLabeledValue(Copy.prepared, value: Copy.date(operation.createdAt)).font(UFitTypography.caption) }
                    Divider().padding(.top, UFitSpace.sm)
                }
            }
            UFitDisclosure(Copy.details) {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    ForEach(document.operations) { operation in
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            beneficiary(operation, document: document)
                            reference(Copy.instruction, value: operation.id)
                            if let receipt = operation.receipt { reference(Copy.receipt, value: receipt.id) }
                        }
                    }
                }
            }
        }
    }
    @ViewBuilder private func beneficiary(_ operation: UFitPaymentDisbursementDocument.Operation, document: UFitPaymentDisbursementDocument) -> some View {
        if let line = document.targets?.lines.first(where: { $0.key == operation.allocationKey }) {
            if line.recipient.kind == .brand { Text(document.allocation.context.brand.name).font(UFitTypography.callout) }
            else if let item = document.allocation.context.creatorItems.first(where: { $0.commissionId == line.recipient.commissionID }) {
                Text(item.creatorName).font(UFitTypography.callout)
                Text(item.itemName).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            }
        }
    }
    private func operationStatus(_ operation: UFitPaymentDisbursementDocument.Operation) -> String {
        switch operation.state { case .recorded: Copy.recorded; case .superseded: Copy.retired; case .open: operation.armed ? Copy.waiting : Copy.preparing }
    }
    private func reference(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xxs) {
            Text(title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            Text(value).font(UFitTypography.caption.monospaced()).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}
