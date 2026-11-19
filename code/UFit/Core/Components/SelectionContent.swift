import SwiftUI

struct UFitSelectionOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var enabled = true
    var id: Value { value }
}
struct UFitSelection<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [UFitSelectionOption<Value>]
    @State private var choosing = false
    private enum Icon { static var next: String { "chevron.down" }; static var check: String { "checkmark" } }
    init(_ title: String, selection: Binding<Value>, options: [UFitSelectionOption<Value>]) {
        self.title = title; _selection = selection; self.options = options
    }
    var body: some View {
        UFitButton { choosing = true } label: {
            HStack(spacing: UFitSpace.sm) {
                Text(options.first(where: { $0.value == selection })?.title ?? UFitFeedbackCopy.choose)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: UFitSpace.xs)
                UFitIcon(systemName: Icon.next).font(UFitTypography.caption).accessibilityHidden(true)
            }.padding(.horizontal, UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.input)
                .background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.field))
                .overlay { RoundedRectangle(cornerRadius: UFitRadius.field).stroke(Color.ufitBorder, lineWidth: UFitSpace.hairline) }
        }.ufitButtonStyle(.text).accessibilityLabel(title)
            .accessibilityValue(options.first(where: { $0.value == selection })?.title ?? UFitFeedbackCopy.choose)
            .ufitSheet(isPresented: $choosing) {
                UFitSelectionList(title: title, selection: $selection, options: options, onClose: { choosing = false })
            }
    }
}
struct UFitSelectionList<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [UFitSelectionOption<Value>]
    let onClose: () -> Void
    @State private var search = String()
    private var filtered: [UFitSelectionOption<Value>] { options.filter { search.isEmpty || $0.title.localizedStandardContains(search) } }
    private enum Icon { static var check: String { "checkmark" } }
    var body: some View {
        VStack(spacing: UFitSpace.md) {
            UFitSheetHeader(title: title, onClose: onClose)
            if options.count > SelectionLayout.searchThreshold { UFitSearchField(query: $search).padding(.horizontal, UFitSpace.page) }
            ScrollView {
                LazyVStack(spacing: .zero) {
                    if filtered.isEmpty { UFitEmptyState(title: UFitFeedbackCopy.empty) }
                    ForEach(filtered) { option in
                        UFitButton {
                            if selection != option.value { selection = option.value }; onClose()
                        } label: {
                            HStack(spacing: UFitSpace.sm) {
                                Text(option.title).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: UFitSpace.xs)
                                if option.value == selection { UFitIcon(systemName: Icon.check).accessibilityHidden(true) }
                            }.padding(.vertical, UFitSpace.sm).frame(maxWidth: .infinity, minHeight: UFitControlSize.input, alignment: .leading)
                        }.ufitButtonStyle(.text).disabled(!option.enabled).accessibilityAddTraits(option.value == selection ? .isSelected : [])
                        Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline)
                    }
                }.padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.xl)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
private enum SelectionLayout { static let searchThreshold = 8 }
struct UFitSearchField: View {
    @Binding var query: String
    var prompt = UFitFeedbackCopy.search
    @FocusState private var focused: Bool
    private enum Icon { static let search = "magnifyingglass"; static let clear = "xmark" }
    private enum Copy { static let clear = String(localized: "Effacer la recherche") }
    var body: some View {
        HStack(spacing: UFitSpace.xs) {
            UFitIcon(systemName: Icon.search).foregroundStyle(Color.ufitSecondaryText).accessibilityHidden(true)
            TextField(prompt, text: $query).textFieldStyle(.plain).font(UFitTypography.body).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focused).accessibilityLabel(prompt).submitLabel(.search)
            if !query.isEmpty { UFitButton { query = String() } label: { UFitIcon(systemName: Icon.clear).font(UFitTypography.caption) }.ufitButtonStyle(.text).accessibilityLabel(Copy.clear) }
        }.padding(.leading, UFitSpace.md).padding(.trailing, query.isEmpty ? UFitSpace.md : UFitSpace.xxs)
            .frame(minHeight: UFitControlSize.input).background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.field))
            .overlay { RoundedRectangle(cornerRadius: UFitRadius.field).stroke(focused ? Color.ufitInk : Color.ufitBorder, lineWidth: UFitSpace.hairline) }.tint(Color.ufitInk)
    }
}

enum UFitChoiceBarAppearance { case outlined, underline, chips }

struct UFitChoiceBar<Value: Hashable>: View {
    private enum Copy { static var separator: String { " : " } }
    let title: String
    @Binding var selection: Value
    let options: [UFitSelectionOption<Value>]
    var appearance: UFitChoiceBarAppearance = .outlined
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: UFitSpace.xs) {
                    ForEach(options) { option in
                        choice(option)
                            .disabled(!option.enabled)
                            .accessibilityAddTraits(option.value == selection ? .isSelected : [])
                            .accessibilityLabel(title + Copy.separator + option.title)
                            .id(option.id)
                    }
                }
            }.scrollIndicators(.hidden)
                .onChange(of: selection) { _, value in proxy.scrollTo(value, anchor: .center) }
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }
    @ViewBuilder private func choice(_ option: UFitSelectionOption<Value>) -> some View {
        if appearance == .chips {
            UFitChoiceChip(selected: option.value == selection, action: { selection = option.value }) {
                Text(option.title)
            }
        } else if appearance == .underline {
            UFitButton { selection = option.value } label: {
                Text(option.title).ufitFont(size: UFitTypography.Size.small, weight: .medium)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(option.value == selection ? Color.ufitInk : Color.ufitSecondaryText)
                    .padding(.horizontal, UFitSpace.xs).frame(minHeight: UFitControlSize.touch)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(option.value == selection ? Color.ufitInk : Color.clear)
                            .frame(height: UFitSpace.hairline)
                    }
            }.ufitButtonStyle(.text)
        } else {
            UFitButton { selection = option.value } label: {
                Text(option.title).font(UFitTypography.subheadline.weight(.medium)).fixedSize(horizontal: true, vertical: false)
            }.ufitButtonStyle(option.value == selection ? .primary : .secondary, compact: true)
        }
    }
}
