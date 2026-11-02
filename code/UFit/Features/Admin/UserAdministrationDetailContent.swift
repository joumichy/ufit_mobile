import SwiftUI

struct UFitUserAdministrationDetailContent: View {
    let document: UFitAdministeredUserDocument
    let history: [UFitUserAccessHistoryRow]
    let isLoading: Bool
    let hasLoadedHistory: Bool
    let hasMore: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onDecide: (UFitUserAccessDecision) -> Void
    let onMore: () -> Void
    private enum Icon { static let refresh = "arrow.clockwise" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitUserAdministrationCopy.account, onBack: onBack) {
                UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh) }
                    .disabled(isLoading).accessibilityLabel(UFitUserAdministrationCopy.refresh)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        Text(document.user.name).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                        if document.user.hasDistinctName { Text(document.user.email).font(UFitTypography.body).foregroundStyle(Color.ufitSecondaryText) }
                    }
                    if let message {
                        UFitNotice(message: message, kind: .error)
                        UFitButton(UFitUserAdministrationCopy.retry, action: onRefresh).ufitButtonStyle(.secondary).disabled(isLoading)
                    }
                    VStack(alignment: .leading, spacing: UFitSpace.md) {
                        UFitEditorialHeading(title: UFitUserAdministrationCopy.access, editorial: false)
                        UFitLabeledValue(UFitUserAdministrationCopy.status, value: document.user.status.label)
                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                            Text(UFitUserAdministrationCopy.roles).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                            Text(document.user.roles.isEmpty ? UFitUserAdministrationCopy.noRoles : document.user.roles.map(\.administrationLabel).joined(separator: UFitUserAdministrationCopy.roleSeparator))
                        }
                        ForEach(document.decisions) { decision in
                            UFitButton(decision.label, role: decision.isDestructive ? .destructive : nil) { onDecide(decision) }
                                .ufitButtonStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    UFitDisclosure(UFitUserAdministrationCopy.accountDetails) {
                        VStack(spacing: UFitSpace.sm) {
                            UFitLabeledValue(UFitUserAdministrationCopy.created, value: document.createdAt)
                            UFitLabeledValue(UFitUserAdministrationCopy.updated, value: document.updatedAt)
                            UFitLabeledValue(UFitUserAdministrationCopy.version, value: String(document.user.version))
                        }.font(UFitTypography.callout)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: UFitSpace.md) {
                        UFitEditorialHeading(title: UFitUserAdministrationCopy.history, editorial: false)
                        if history.isEmpty {
                            if isLoading || (!hasLoadedHistory && message == nil) { UFitLoading(UFitUserAdministrationCopy.loadingHistory) }
                            else if hasLoadedHistory && message == nil { Text(UFitUserAdministrationCopy.noHistory).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                        } else {
                            ForEach(history) { change in
                                VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                    Text(change.decision.historyLabel).font(UFitTypography.headline)
                                    Text(change.date).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                    Text(change.reason).font(UFitTypography.body)
                                    UFitDisclosure(UFitUserAdministrationCopy.details) {
                                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                            UFitLabeledValue(UFitUserAdministrationCopy.version, value: String(change.version))
                                            Text(UFitUserAdministrationCopy.author).foregroundStyle(Color.ufitSecondaryText)
                                            Text(change.actorID).fixedSize(horizontal: false, vertical: true)
                                        }.font(UFitTypography.caption)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Divider()
                            }
                            if isLoading { UFitLoading() }
                            if hasMore { UFitButton(UFitUserAdministrationCopy.more, action: onMore).ufitButtonStyle(.secondary).disabled(isLoading) }
                        }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
