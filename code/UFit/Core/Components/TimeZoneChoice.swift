import SwiftUI

struct UFitTimeZoneChoice: View {
    let identifier: String
    let date: Date
    let onSelect: (String) -> Void
    @State private var expanded = false
    @State private var query = String()
    private enum Copy {
        static let title = String(localized: "Fuseau horaire")
        static let search = String(localized: "Rechercher une ville ou une région")
        static let device = String(localized: "Fuseau de l’appareil")
        static let empty = String(localized: "Aucun fuseau ne correspond à cette recherche.")
        static let refine = String(localized: "D’autres fuseaux correspondent. Précisez votre recherche.")
        static let close = String(localized: "Fermer le choix du fuseau")
        static let separator = " · "
    }
    private enum Icon {
        static let expanded = "chevron.up"
        static let collapsed = "chevron.down"
        static let selected = "checkmark.circle.fill"
    }
    private enum Layout {
        static let columns = 2
        static let resultLimit = 6
    }
    private var searchTerm: String { UFitTimeZoneFormatting.searchable(query.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var matches: [String] {
        let candidates = (searchTerm.isEmpty ? [identifier, TimeZone.current.identifier] : TimeZone.knownTimeZoneIdentifiers)
            + [UFitTimeZoneFormatting.universalIdentifier]
        return Array(Set(candidates)).sorted().filter {
            searchTerm.isEmpty || UFitTimeZoneFormatting.searchable($0).localizedStandardContains(searchTerm)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            UFitButton { expanded.toggle(); if !expanded { query = String() } } label: {
                HStack(spacing: UFitSpace.sm) {
                    VStack(alignment: .leading, spacing: UFitSpace.xxs) {
                        Text(Copy.title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        Text(UFitTimeZoneFormatting.city(identifier) + Copy.separator + UFitTimeZoneFormatting.offset(identifier, at: date))
                            .font(UFitTypography.callout.weight(.medium)).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: UFitSpace.xs)
                    UFitIcon(systemName: expanded ? Icon.expanded : Icon.collapsed).font(UFitTypography.caption)
                }.frame(maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
            }.ufitButtonStyle(.text).accessibilityLabel(Copy.title)
                .accessibilityValue(UFitTimeZoneFormatting.city(identifier) + Copy.separator + UFitTimeZoneFormatting.offset(identifier, at: date))
            if expanded {
                UFitSearchField(query: $query, prompt: Copy.search)
                if matches.isEmpty { Text(Copy.empty).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: UFitSpace.xs), count: Layout.columns), spacing: UFitSpace.xs) {
                    ForEach(Array(matches.prefix(Layout.resultLimit)), id: \.self) { value in option(value) }
                }
                if matches.count > Layout.resultLimit { Text(Copy.refine).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                UFitButton(Copy.close) { expanded = false; query = String() }.ufitButtonStyle(.text).font(UFitTypography.caption)
            }
        }
    }
    private func option(_ value: String) -> some View {
        let selected = value == identifier
        return UFitButton {
            onSelect(value); expanded = false; query = String()
        } label: {
            VStack(alignment: .leading, spacing: UFitSpace.xxs) {
                HStack(alignment: .top, spacing: UFitSpace.xxs) {
                    Text(UFitTimeZoneFormatting.city(value)).font(UFitTypography.subheadline.weight(.medium))
                    Spacer(minLength: .zero)
                    if selected { UFitIcon(systemName: Icon.selected).font(UFitTypography.caption).accessibilityHidden(true) }
                }
                Text(UFitTimeZoneFormatting.offset(value, at: date)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                Text(UFitTimeZoneFormatting.region(value)).font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText)
                if value == TimeZone.current.identifier { Text(Copy.device).font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText) }
            }.multilineTextAlignment(.leading).frame(maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
                .padding(UFitSpace.sm).background(selected ? Color.ufitSecondary : Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.field))
                .overlay { RoundedRectangle(cornerRadius: UFitRadius.field).stroke(selected ? Color.ufitInk : Color.ufitBorder, lineWidth: UFitSpace.hairline) }
        }.ufitButtonStyle(.text).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

enum UFitTimeZoneFormatting {
    static let universalIdentifier = "UTC"
    private enum Value {
        static let path: Character = "/"
        static let underscore = "_"
        static let space = " "
        static let utc = "UTC"
        static let plus = "+"
        static let minus = "−"
        static let separator = ":"
        static let regionSeparator = " · "
        static let secondsPerMinute = 60
        static let minutesPerHour = 60
    }
    static func city(_ identifier: String) -> String {
        String(identifier.split(separator: Value.path).last ?? Substring(identifier)).replacingOccurrences(of: Value.underscore, with: Value.space)
    }
    static func searchable(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: String(Value.path), with: Value.space).replacingOccurrences(of: Value.underscore, with: Value.space)
    }
    static func region(_ identifier: String) -> String {
        identifier.split(separator: Value.path).dropLast().joined(separator: Value.regionSeparator)
    }
    static func offset(_ identifier: String, at date: Date) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return identifier }
        let seconds = zone.secondsFromGMT(for: date)
        guard seconds != .zero else { return Value.utc }
        let minutes = abs(seconds) / Value.secondsPerMinute
        return Value.utc + (seconds > .zero ? Value.plus : Value.minus)
            + UFitPublicationCalendarMath.minuteLabel(minutes / Value.minutesPerHour) + Value.separator
            + UFitPublicationCalendarMath.minuteLabel(minutes % Value.minutesPerHour)
    }
}
