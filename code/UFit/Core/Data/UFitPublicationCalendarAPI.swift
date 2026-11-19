import Foundation

enum UFitPublicationDate {
    static func parse(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
    static func encode(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
}

enum UFitPublicationHTTP {
    static let calendar = "outfits/calendar"
    static let publication = "/publication"
    static let from = "from"
    static let until = "until"
}

struct UFitPublicationCalendarPage: Decodable {
    let items: [UFitManagedOutfit]
    let nextCursor: String?
    let asOf: String
}

extension UFitAPIClient {
    func fetchPublicationCalendar(scope: UFitOutfitScope, from: Date, until: Date, cursor: String?) async throws -> UFitPublicationCalendarPage {
        var query = [UFitOutfitEditingHTTP.ownerQuery(scope),
                     URLQueryItem(name: UFitPublicationHTTP.from, value: UFitPublicationDate.encode(from)),
                     URLQueryItem(name: UFitPublicationHTTP.until, value: UFitPublicationDate.encode(until)),
                     URLQueryItem(name: UFitOutfitEditingHTTP.limit, value: String(UFitOutfitEditingHTTP.pageLimit))]
        if let cursor { query.append(.init(name: UFitOutfitEditingHTTP.cursor, value: cursor)) }
        let page: UFitPublicationCalendarPage = try await send(UFitOutfitEditingHTTP.get, path: UFitPublicationHTTP.calendar, query: query, requiresAuth: true)
        for item in page.items {
            try item.validate(scope: scope)
            guard let text = item.scheduledFor, let date = UFitPublicationDate.parse(text), date >= from, date < until else { throw UFitOutfitContractError.page }
        }
        guard UFitPublicationDate.parse(page.asOf) != nil, Set(page.items.map(\.id)).count == page.items.count,
              page.nextCursor == nil || (page.nextCursor == page.items.last?.id && page.nextCursor != cursor) else { throw UFitOutfitContractError.page }
        return page
    }

    func planOutfitPublication(_ revision: UFitOutfitRevision, date: Date?, timeZone: String?) async throws -> UFitManagedOutfit {
        struct Body: Encodable {
            let expectedVersion: Int
            let scheduledFor: String?
            let timeZone: String?
            enum CodingKeys: String, CodingKey { case expectedVersion, scheduledFor, timeZone }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(expectedVersion, forKey: .expectedVersion)
                try container.encode(scheduledFor, forKey: .scheduledFor)
                try container.encode(timeZone, forKey: .timeZone)
            }
        }
        let result: UFitManagedOutfit = try await send(UFitOutfitEditingHTTP.patch,
            path: UFitOutfitEditingHTTP.base + revision.id + UFitPublicationHTTP.publication,
            body: Body(expectedVersion: revision.version, scheduledFor: date.map(UFitPublicationDate.encode), timeZone: timeZone), requiresAuth: true, publicOutfitsChange: true)
        try result.validate(id: revision.id)
        return result
    }
}
