import SwiftUI
import Observation

@MainActor @Observable
final class UFitCreatorGradeAdministrationStore {
    var section = UFitCreatorGradeAdministrationSection.assignments
    let assignments: UFitCreatorGradeAssignmentsStore
    let definitions: UFitCreatorGradesStore
    init(session: UFitSessionStore) {
        assignments = UFitCreatorGradeAssignmentsStore(session: session)
        definitions = UFitCreatorGradesStore(session: session)
    }
    var isCurrentAccount: Bool { assignments.isCurrentAccount && definitions.isCurrentAccount }
}

struct UFitCreatorGradeAdministrationHost: View {
    let store: UFitCreatorGradeAdministrationStore
    let onBack: () -> Void
    let onCreate: () -> Void
    let onDefinition: (UFitCreatorGradeDetailStore) -> Void
    let onAssignment: (UFitCreatorGradeAssignmentDetailStore) -> Void
    var body: some View {
        Group {
            if store.isCurrentAccount {
                switch store.section {
                case .assignments:
                    UFitCreatorGradeAssignmentsHost(store: store.assignments, onBack: onBack,
                        onDefinitions: { store.section = .definitions }, onOpen: onAssignment)
                case .definitions:
                    UFitCreatorGradesHost(store: store.definitions, onBack: onBack,
                        onAssignments: { store.section = .assignments }, onCreate: onCreate, onOpen: onDefinition)
                }
            } else { UFitCreatorGradeAccessUnavailable(onBack: onBack) }
        }
    }
}

struct UFitCreatorGradesHost: View {
    let store: UFitCreatorGradesStore
    let onBack: () -> Void
    let onAssignments: () -> Void
    let onCreate: () -> Void
    let onOpen: (UFitCreatorGradeDetailStore) -> Void
    var body: some View {
        @Bindable var list = store
        UFitCreatorGradesContent(grades: store.rows, search: $list.search,
            assignable: Binding(get: { store.assignable }, set: { value in Task { await store.filter(assignable: value) } }),
            hasLoaded: store.hasLoaded, isLoading: store.isLoading, hasMore: store.nextCursor != nil,
            openingIDs: store.openingIDs, message: store.message, onBack: onBack, onAssignments: onAssignments,
            onSearch: { Task { await store.load() } },
            onReset: { store.search = String(); Task { await store.filter(assignable: nil) } }, onCreate: onCreate,
            onOpen: { code in Task { if let detail = await store.open(code) { onOpen(detail) } } },
            onMore: { Task { await store.load(refresh: false) } })
            .task { await store.load() }.onDisappear { store.cancelLoading() }
            .onChange(of: store.search) { previous, current in
                if !UFitServerTextInput.trimmed(previous).isEmpty && UFitServerTextInput.trimmed(current).isEmpty { Task { await store.load() } }
            }
    }
}

struct UFitCreatorGradeAssignmentsHost: View {
    let store: UFitCreatorGradeAssignmentsStore
    let onBack: () -> Void
    let onDefinitions: () -> Void
    let onOpen: (UFitCreatorGradeAssignmentDetailStore) -> Void
    var body: some View {
        @Bindable var list = store
        UFitCreatorGradeAssignmentsContent(assignments: store.assignments.map(\.presentation), search: $list.search,
            hasLoaded: store.hasLoaded, isLoading: store.isLoading, hasMore: store.nextCursor != nil,
            openingIDs: store.openingIDs, message: store.message, onBack: onBack, onDefinitions: onDefinitions,
            onSearch: { Task { await store.load() } }, onReset: { store.search = String(); Task { await store.load() } },
            onOpen: { id in Task { if let detail = await store.open(id) { onOpen(detail) } } },
            onMore: { Task { await store.load(refresh: false) } })
            .task { await store.load() }.onDisappear { store.cancelLoading() }
            .onChange(of: store.search) { previous, current in
                if !UFitServerTextInput.trimmed(previous).isEmpty && UFitServerTextInput.trimmed(current).isEmpty { Task { await store.load() } }
            }
    }
}

struct UFitCreatorGradeDetailHost: View {
    let store: UFitCreatorGradeDetailStore
    let onBack: () -> Void
    let onRevise: () -> Void
    var body: some View {
        Group {
            if store.isCurrentAccount {
                UFitCreatorGradeDetailContent(grade: store.grade.row, history: store.history, hasLoadedHistory: store.hasLoadedHistory,
                    isLoading: store.isLoading, hasMore: store.nextCursor != nil, message: store.message, canRevise: true,
                    onBack: onBack, onRefresh: { Task { await store.load() } }, onRevise: onRevise,
                    onMore: { Task { await store.load(refresh: false) } })
            } else { UFitCreatorGradeAccessUnavailable(onBack: onBack) }
        }.task { await store.load() }.onDisappear { store.cancelLoading() }
    }
}

struct UFitCreatorGradeAssignmentDetailHost: View {
    let store: UFitCreatorGradeAssignmentDetailStore
    let onBack: () -> Void
    let onChangeGrade: () -> Void
    var body: some View {
        Group {
            if store.isCurrentAccount {
                UFitCreatorGradeAssignmentDetailContent(assignment: store.assignment.presentation, history: store.history.map(\.presentation),
                    hasLoadedHistory: store.hasLoadedHistory, isLoading: store.isLoading, hasMore: store.nextCursor != nil,
                    message: store.message, canChangeGrade: store.canChangeGrade, ineligibilityMessage: store.assignment.ineligibilityMessage,
                    onBack: onBack, onRefresh: { Task { await store.load() } }, onChangeGrade: onChangeGrade,
                    onMore: { Task { await store.load(refresh: false) } })
            } else { UFitCreatorGradeAccessUnavailable(onBack: onBack) }
        }.task { await store.load() }.onDisappear { store.cancelLoading() }
    }
}

struct UFitCreatorGradeAccessUnavailable: View {
    let onBack: () -> Void
    var body: some View {
        UFitEmptyState(title: CreatorGradePresentationCopy.unavailable,
            actionTitle: CreatorGradePresentationCopy.back, action: onBack)
    }
}
