import SwiftUI

struct UFitUserAdministrationContent: View {
    let users: [UFitAdministeredUserRow]
    @Binding var search: String
    @Binding var status: UFitAccountStatus?
    @Binding var role: UFitUserRole?
    let isLoading: Bool
    let hasLoaded: Bool
    let openingIDs: Set<String>
    let hasMore: Bool
    let message: String?
    let onBack: () -> Void
    let onSearch: () -> Void
    let onRefresh: () -> Void
    let onReset: () -> Void
    let onOpen: (String) -> Void
    let onMore: () -> Void
    private enum Icon { static let refresh = "arrow.clockwise"; static let next = "chevron.right"; static let empty = "person.2" }
    private var filtered: Bool { !UFitServerTextInput.trimmed(search).isEmpty || status != nil || role != nil }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitUserAdministrationCopy.title, onBack: onBack) {
                UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh) }
                    .disabled(isLoading).accessibilityLabel(UFitUserAdministrationCopy.refresh)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    UFitSearchField(query: $search, prompt: UFitUserAdministrationCopy.search).onSubmit(onSearch)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: UFitSpace.sm) { statusFilter; roleFilter }
                        VStack(spacing: UFitSpace.sm) { statusFilter; roleFilter }
                    }
                    if let message {
                        UFitNotice(message: message, kind: .error)
                        UFitButton(UFitUserAdministrationCopy.retry, action: onRefresh).ufitButtonStyle(.secondary).disabled(isLoading)
                    }
                    if users.isEmpty {
                        if isLoading || (!hasLoaded && message == nil) {
                            UFitLoading(UFitUserAdministrationCopy.loading).frame(maxWidth: .infinity).padding(.vertical, UFitSpace.xl)
                        } else if hasLoaded && message == nil {
                            UFitEmptyState(title: filtered ? UFitUserAdministrationCopy.noMatches : UFitUserAdministrationCopy.empty,
                                symbol: Icon.empty, actionTitle: filtered ? UFitUserAdministrationCopy.allUsers : nil, action: filtered ? onReset : nil)
                        }
                    } else {
                        LazyVStack(spacing: .zero) {
                            ForEach(users) { user in
                                UFitButton { onOpen(user.id) } label: {
                                    HStack(alignment: .top, spacing: UFitSpace.md) {
                                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                            Text(user.name).font(UFitTypography.headline)
                                            if user.hasDistinctName { Text(user.email).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText) }
                                            Text(user.status.label).font(UFitTypography.caption)
                                        }.fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: UFitSpace.sm)
                                        if openingIDs.contains(user.id) { UFitLoading() }
                                        else { UFitIcon(systemName: Icon.next).font(UFitTypography.caption).accessibilityHidden(true) }
                                    }.padding(.vertical, UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
                                }.disabled(openingIDs.contains(user.id))
                                Divider()
                            }
                        }
                        if isLoading { UFitLoading().frame(maxWidth: .infinity) }
                        if hasMore { UFitButton(UFitUserAdministrationCopy.more, action: onMore).ufitButtonStyle(.secondary).disabled(isLoading) }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private var statusFilter: some View {
        UFitSelection(UFitUserAdministrationCopy.status, selection: $status, options:
            [.init(value: Optional<UFitAccountStatus>.none, title: UFitUserAdministrationCopy.allStatuses)] +
            UFitAccountStatus.allCases.map { .init(value: Optional($0), title: $0.label) })
    }
    private var roleFilter: some View {
        UFitSelection(UFitUserAdministrationCopy.role, selection: $role, options:
            [.init(value: Optional<UFitUserRole>.none, title: UFitUserAdministrationCopy.allRoles)] +
            UFitUserRole.allCases.map { .init(value: Optional($0), title: $0.administrationLabel) })
    }
}
