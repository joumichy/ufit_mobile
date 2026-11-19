import Foundation
import Observation

@MainActor @Observable
final class UFitOutfitPublicationStore: Identifiable {
    let id = UUID()
    let outfit: UFitManagedOutfitStore
    let revision: UFitOutfitRevision
    var day: Date { didSet {
        if !calendar.isDate(oldValue, inSameDayAs: day) { selectedOccurrence = nil }
        clearTimeValidationError()
    } }
    var month: Date
    var hourText: String { didSet {
        if UFitPublicationCalendarMath.timeValue(oldValue, upperBound: UFitPublicationCalendarMath.hourCount)
            != UFitPublicationCalendarMath.timeValue(hourText, upperBound: UFitPublicationCalendarMath.hourCount) { selectedOccurrence = nil }
        clearTimeValidationError()
    } }
    var minuteText: String { didSet {
        if UFitPublicationCalendarMath.timeValue(oldValue, upperBound: UFitPublicationCalendarMath.minuteCount)
            != UFitPublicationCalendarMath.timeValue(minuteText, upperBound: UFitPublicationCalendarMath.minuteCount) { selectedOccurrence = nil }
        clearTimeValidationError()
    } }
    var timeZoneID: String { didSet {
        if oldValue != timeZoneID { selectedOccurrence = nil }
        clearTimeValidationError()
    } }
    private(set) var isSaving = false
    private(set) var message: String?
    private(set) var hasSaved = false
    @ObservationIgnored private var hasTimeValidationError = false
    private var selectedOccurrence: Date?
    @ObservationIgnored private let initialDate: Date
    @ObservationIgnored private let initialZone: String
    @ObservationIgnored private let initialComponents: DateComponents
    private enum Copy {
        static let invalidTime = String(localized: "Indiquez des heures de 00 à 23 et des minutes de 00 à 59.")
        static let invalidZoneTime = String(localized: "Cette heure n’existe pas dans le fuseau choisi. Modifiez l’heure ou le jour.")
        static let repeatedTime = String(localized: "Choisissez le premier ou le second passage de cette heure.")
        static let past = String(localized: "Choisissez une date et une heure à venir.")
        static let changed = String(localized: "La tenue a changé. Fermez puis actualisez-la avant de programmer.")
        static let unconfirmed = String(localized: "La programmation n’a pas pu être confirmée. Réessayez.")
    }
    private enum ServiceResponse { static let serverErrorMinimum = 500 }
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
    private var wallComponents: DateComponents? {
        guard let hour = UFitPublicationCalendarMath.timeValue(hourText, upperBound: UFitPublicationCalendarMath.hourCount),
              let minute = UFitPublicationCalendarMath.timeValue(minuteText, upperBound: UFitPublicationCalendarMath.minuteCount) else { return nil }
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour; parts.minute = minute
        return parts
    }
    var occurrences: [Date] {
        guard let components = wallComponents, let hour = components.hour, let minute = components.minute else { return [] }
        return UFitPublicationCalendarMath.occurrences(on: day, hour: hour, minute: minute, zone: zone)
    }
    var isRepeatedTime: Bool { occurrences.count > UFitPublicationCalendarMath.singleOccurrence }
    private var matchesInitialTime: Bool { timeZoneID == initialZone && wallComponents == initialComponents }
    private var initialMinute: Date? { calendar.dateInterval(of: .minute, for: initialDate)?.start }
    var chosenOccurrence: Date? {
        let choices = occurrences
        if let selectedOccurrence, choices.contains(selectedOccurrence) { return selectedOccurrence }
        if matchesInitialTime, let initialMinute, choices.contains(initialMinute) { return initialMinute }
        return choices.count == UFitPublicationCalendarMath.singleOccurrence ? choices.first : nil
    }
    var date: Date? {
        guard let chosenOccurrence else { return nil }
        // Retain saved seconds and the exact occurrence until the author's wall time changes.
        if matchesInitialTime, chosenOccurrence == initialMinute { return initialDate }
        return chosenOccurrence
    }
    func chooseOccurrence(_ value: Date?) {
        guard !isSaving, let value, occurrences.contains(value) else { return }
        selectedOccurrence = value
        clearTimeValidationError()
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
        guard cancel || !isRepeatedTime || selected != nil else { rejectTime(Copy.repeatedTime); return }
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
                if (error as? UFitAPIError)?.isOutfitVersionConflict == true { message = Copy.changed }
                else if case UFitAPIError.requestFailed(let status, _, _) = error, status >= ServiceResponse.serverErrorMinimum {
                    message = Copy.unconfirmed
                } else { message = error.localizedDescription }
            }
        }
    }
}
