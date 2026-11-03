import Foundation

struct UFitRevenuePointDTO: Decodable, Identifiable {
    let date: String
    let orders: Int; let captured: Int; let refunded: Int; let refundPending: Int; let salesNet: Int
    let original: Int; let adjusted: Int; let commissionNet: Int
    let estimated: Int; let pending: Int; let available: Int; let paid: Int; let paidAdjustment: Int
    var id: String { date }
    var commissionAmounts: [Int] { [original, adjusted, commissionNet, estimated, pending, available, paid, paidAdjustment] }
    var amounts: [Int] { [orders, captured, refunded, refundPending, salesNet] + commissionAmounts }
    func amount(_ metric: UFitRevenueMetric) -> Int {
        switch metric {
        case .salesNet: salesNet
        case .captured: captured
        case .refunded: refunded
        case .commissionNet: commissionNet
        case .original: original
        case .adjusted: adjusted
        }
    }
    func validate() throws {
        guard UFitRevenueCalendar.parse(date) != nil, amounts.allSatisfy(UFitWorkspaceFinanceContract.integer),
              UFitWorkspaceFinanceContract.sum([refunded, salesNet]) == captured,
              let committed = UFitWorkspaceFinanceContract.sum([refunded, refundPending]), committed <= captured,
              UFitWorkspaceFinanceContract.sum([adjusted, commissionNet]) == original,
              let states = UFitWorkspaceFinanceContract.sum([estimated, pending, available, paid]), states - paidAdjustment == commissionNet,
              paidAdjustment <= paid else { throw UFitWorkspaceFinanceFailure.document }
    }
}
struct UFitRevenueCurrencyDTO: Decodable, Identifiable {
    let currency: String
    let points: [UFitRevenuePointDTO]
    var id: String { currency }
    func total(_ metric: UFitRevenueMetric) -> Int { points.reduce(.zero) { $0 + $1.amount(metric) } }
}
struct UFitWorkspaceRevenueDTO: Decodable {
    enum Granularity: String, Decodable { case day, week, month }
    let profileId: String
    let kind: UFitRevenueScope
    let basis: UFitWorkspaceSalesBasis
    let period: UFitRevenuePeriod
    let granularity: Granularity
    let start: String; let end: String
    let asOf: UFitTimestamp
    let currencies: [UFitRevenueCurrencyDTO]
    func validate(workspace: UFitWorkspaceReference, period expectedPeriod: UFitRevenuePeriod) throws {
        let calendar = UFitRevenueCalendar.calendar
        let today = calendar.startOfDay(for: asOf.value)
        let expectedStart: Date?
        let expectedGranularity: Granularity
        switch period {
        case .month: expectedStart = calendar.date(byAdding: .day, value: -UFitRevenueContract.monthDays + UFitRevenueContract.step, to: today); expectedGranularity = .day
        case .quarter: expectedStart = calendar.date(byAdding: .day, value: -UFitRevenueContract.quarterDays + UFitRevenueContract.step, to: today); expectedGranularity = .week
        case .year:
            expectedStart = calendar.date(byAdding: .month, value: -UFitRevenueContract.yearMonths + UFitRevenueContract.step, to: calendar.dateInterval(of: .month, for: today)!.start)
            expectedGranularity = .month
        }
        guard profileId == workspace.profileID, kind == (workspace.isCreator ? .creator : .brand), period == expectedPeriod,
              basis == (workspace.isCreator ? .attributedMerchandise : .orderTotal), granularity == expectedGranularity,
              let startDate = UFitRevenueCalendar.parse(start), startDate == expectedStart,
              let endDate = UFitRevenueCalendar.parse(end), endDate == calendar.date(byAdding: .day, value: UFitRevenueContract.step, to: today),
              Set(currencies.map(\.currency)).count == currencies.count else { throw UFitWorkspaceFinanceFailure.document }
        var tick = granularity == .week ? calendar.dateInterval(of: .weekOfYear, for: startDate)!.start : startDate
        var dates: [Date] = []
        while tick < endDate {
            dates.append(tick)
            tick = calendar.date(byAdding: granularity == .month ? .month : .day, value: granularity == .week ? UFitRevenueContract.weekDays : UFitRevenueContract.step, to: tick)!
        }
        for currency in currencies {
            guard UFitWorkspaceFinanceContract.currency(currency.currency), currency.points.count == dates.count else { throw UFitWorkspaceFinanceFailure.document }
            for (index, point) in currency.points.enumerated() {
                try point.validate()
                guard UFitRevenueCalendar.parse(point.date) == dates[index], workspace.isCreator || point.commissionAmounts.allSatisfy({ $0 == .zero }) else { throw UFitWorkspaceFinanceFailure.document }
            }
            for index in 0..<(currency.points.first?.amounts.count ?? .zero) {
                guard let total = UFitWorkspaceFinanceContract.sum(currency.points.map { $0.amounts[index] }), UFitWorkspaceFinanceContract.integer(total) else { throw UFitWorkspaceFinanceFailure.document }
            }
        }
    }
}
