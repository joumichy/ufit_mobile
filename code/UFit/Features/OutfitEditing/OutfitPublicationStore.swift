import Foundation
import Observation

@MainActor @Observable
final class UFitOutfitPublicationStore: Identifiable {
    let id = UUID()
    let outfit: UFitManagedOutfitStore
    let revision: UFitOutfitRevision
    var day: Date { didSet { clearTimeValidationError() } }
    var month: Date
    var hourText: String { didSet { clearTimeValidationError() } }
    var minuteText: String { didSet { clearTimeValidationError() } }
    var timeZoneID: String
    private(set) var isSaving = false
    private(set) var message: String?
    private(set) var hasSaved = false
    @ObservationIgnored private var hasTimeValidationError = false
    @ObservationIgnored private let initialDate: Date
    @ObservationIgnored private let initialZone: String
    @ObservationIgnored private let initialComponents: DateComponents
    private enum Copy {
        static let invalidTime = String(localized: "Indiquez des heures de 00 à 23 et des minutes de 00 à 59.")
        static let invalidZoneTime = String(localized: "Cette heure n’existe pas dans le fuseau choisi. Modifiez l’heure ou le jour.")
        static let past = String(localized: "Choisissez une date et une heure à venir.")
        static let changed = String(localized: "La tenue a changé. Fermez puis actualisez-la avant de programmer.")
    }
    init(outfit: UFitManagedOutfitStore) {
        self.outfit = outfit; revision = outfit.document.revision
        let savedIdentifier = outfit.document.publicationTimeZone.flatMap { TimeZone(identifier: $0) == nil ? nil : $0 }
        let zone = savedIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        let calendar = UFitPublicationCalendarMath.calendar(zone: zone)
        let proposed = Date().addingTimeInterval(UFitPublicationCalendarMath.initialDelay)
        let initial = outfit.document.scheduledFor.map { UFitPublicationDate.parse($0)! }
            ?? calendar.dateInterval(of: .minute, for: proposed)!.start
        day = initial; month = initial
        hourText = UFitPublicationCalendarMath.minuteLabel(calendar.component(.hour, from: initial))
        minuteText = UFitPublicationCalendarMath.minuteLabel(calendar.component(.minute, from: initial))
        timeZoneID = savedIdentifier ?? zone.identifier
        initialDate = initial
        initialZone = savedIdentifier ?? zone.identifier
        initialComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: initial)
    }
    var zone: TimeZone { TimeZone(identifier: timeZoneID)! }
    var calendar: Calendar { UFitPublicationCalendarMath.calendar(zone: zone) }
    var hasValidTime: Bool {
        UFitPublicationCalendarMath.timeValue(hourText, upperBound: UFitPublicationCalendarMath.hourCount) != nil &&
        UFitPublicationCalendarMath.timeValue(minuteText, upperBound: UFitPublicationCalendarMath.minuteCount) != nil
    }
    var hasChanges: Bool { date != initialDate || timeZoneID != initialZone }
    var date: Date? {
        guard let hour = UFitPublicationCalendarMath.timeValue(hourText, upperBound: UFitPublicationCalendarMath.hourCount),
              let minute = UFitPublicationCalendarMath.timeValue(minuteText, upperBound: UFitPublicationCalendarMath.minuteCount) else { return nil }
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour; parts.minute = minute
        // Keep the saved instant when its wall time is unchanged, including a repeated DST hour.
        if timeZoneID == initialZone, parts == initialComponents { return initialDate }
        guard let value = calendar.date(from: parts), calendar.component(.hour, from: value) == hour,
              calendar.component(.minute, from: value) == minute else { return nil }
        return value
    }
    func moveMonth(_ amount: Int) { if let value = calendar.date(byAdding: .month, value: amount, to: month) { month = value } }
    func changeZone(_ identifier: String) {
        guard let zone = TimeZone(identifier: identifier) else { return }
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let newCalendar = UFitPublicationCalendarMath.calendar(zone: zone)
        timeZoneID = identifier
        if let value = newCalendar.date(from: parts) { day = value; month = value }
        message = nil
        hasTimeValidationError = false
    }
    private func clearTimeValidationError() {
        guard hasTimeValidationError else { return }
        hasTimeValidationError = false
        message = nil
    }
    private func rejectTime(_ reason: String) {
        hasTimeValidationError = true
        message = reason
    }
    func save(cancel: Bool = false) async {
        guard !isSaving, outfit.collection.isCurrentAccount else { return }
        hasTimeValidationError = false
        guard outfit.document.revision == revision else { message = Copy.changed; return }
        let selected = date
        guard cancel || hasValidTime else { rejectTime(Copy.invalidTime); return }
        guard cancel || selected != nil else { rejectTime(Copy.invalidZoneTime); return }
        guard cancel || selected! > Date() else { rejectTime(Copy.past); return }
        isSaving = true; message = nil
        defer { isSaving = false }
        do {
            let result = try await outfit.collection.client.planOutfitPublication(revision, date: cancel ? nil : selected, timeZone: cancel ? nil : timeZoneID)
            guard outfit.collection.isCurrentAccount else { return }
            try outfit.receive(result); hasSaved = true
        } catch {
            if outfit.collection.isCurrentAccount {
                message = (error as? UFitAPIError)?.isOutfitVersionConflict == true ? Copy.changed : error.localizedDescription
            }
        }
    }
}
