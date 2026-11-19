import Foundation

/// Shares identical reads in flight. Only explicitly validated reference data is retained.
actor UFitAPIReadReuse {
    enum Scope: Hashable { case account, reference, publicOutfits }
    struct Reference {
        let reload: Bool
        let validate: @Sendable (Data) throws -> Void
    }
    enum Policy {
        static let get = "GET"
        static let referenceLifetime: TimeInterval = 300
        static let maximumReferences = 16
        static let success = 200..<300
    }
    private struct Header: Hashable { let name: String; let value: String }
    private struct Key: Hashable {
        let scope: Scope
        let url: URL?
        let headers: [Header]
        let cachePolicy: UInt
        init(_ request: URLRequest, scope: Scope) {
            self.scope = scope
            url = request.url
            headers = (request.allHTTPHeaderFields ?? [:]).map { Header(name: $0.key.lowercased(), value: $0.value) }
                .sorted { $0.name == $1.name ? $0.value < $1.value : $0.name < $1.name }
            cachePolicy = request.cachePolicy.rawValue
        }
    }
    private struct Flight {
        let id: UUID
        let generation: UUID
        let task: Task<ReceivedRead, Error>
    }
    private struct ReceivedRead { let data: Data; let response: URLResponse; let receivedAt: Date }
    private struct Entry {
        let data: Data
        let response: URLResponse
        let storedAt: Date
        var isFresh: Bool {
            let age = Date().timeIntervalSince(storedAt)
            return age >= .zero && age < Policy.referenceLifetime
        }
    }
    private var accountGeneration = UUID()
    private var referenceGeneration = UUID()
    private var publicOutfitsGeneration = UUID()
    private var flights = [Key: Flight]()
    private var references = [Key: Entry]()

    func generation(for scope: Scope) -> UUID {
        switch scope {
        case .account: accountGeneration
        case .reference: referenceGeneration
        case .publicOutfits: publicOutfitsGeneration
        }
    }

    func invalidateAccount() {
        accountGeneration = UUID()
        referenceGeneration = UUID()
        flights = flights.filter { $0.key.scope == .publicOutfits }
        references = [:]
    }

    func invalidateMutation(publicOutfitsChange: Bool) {
        accountGeneration = UUID()
        if publicOutfitsChange { publicOutfitsGeneration = UUID() }
        // A saved outfit, payment or upload does not change countries, currencies or tags.
        flights = flights.filter { $0.key.scope == .reference || ($0.key.scope == .publicOutfits && !publicOutfitsChange) }
    }

    func data(for request: URLRequest, session: URLSession, scope: Scope, context: UUID, reference: Reference?) async throws -> (Data, URLResponse) {
        let key = Key(request, scope: scope)
        references = references.filter { $0.value.isFresh }
        if context == generation(for: scope), reference?.reload == true { references[key] = nil }
        if context == generation(for: scope), let reference, !reference.reload, let entry = references[key] {
            try Task.checkCancellation()
            return (entry.data, entry.response)
        }
        let flight: Flight
        if context == generation(for: scope), let existing = flights[key], existing.generation == context {
            flight = existing
        } else {
            flight = Flight(id: UUID(), generation: context, task: Task {
                let (data, response) = try await session.data(for: request)
                return ReceivedRead(data: data, response: response, receivedAt: Date())
            })
            if context == generation(for: scope) { flights[key] = flight }
        }
        defer { if flights[key]?.id == flight.id { flights[key] = nil } }
        let result = try await flight.task.value
        try Task.checkCancellation()
        if let reference, let response = result.response as? HTTPURLResponse,
           Policy.success.contains(response.statusCode), !result.data.isEmpty {
            try reference.validate(result.data)
            // An older read may finish, but can never replenish a later context.
            if generation(for: scope) == context {
                if references.count >= Policy.maximumReferences, references[key] == nil { references = [:] }
                references[key] = Entry(data: result.data, response: result.response, storedAt: result.receivedAt)
            }
        }
        return (result.data, result.response)
    }
}
