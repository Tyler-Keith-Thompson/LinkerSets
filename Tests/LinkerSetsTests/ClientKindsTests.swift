// Clients in one binary, each with its own kind and macro (ExampleRoutes' @Route,
// ExampleMigrations' @Migration, ExampleEvents' @Event), find their own records and never each
// other's. Each test is self-contained.

#if objectFormat(MachO) || objectFormat(ELF)
import ExampleEvents
import ExampleMigrations
import ExampleRoutes
import LinkerSets
import Testing

@Suite("Client kinds")
struct ClientKindsTests {
    @Test("A client's set holds the records its macro declared in its module")
    func routes() {
        let sut = LinkerSet<Endpoint>(kind: .routes)
        let expected = ["/", "/settings"]

        let actual = sut.values.map(\.path).sorted()

        #expect(actual == expected)
    }

    @Test("A second client's functions are found as values of their function type")
    func migrations() {
        let sut = LinkerSet<(inout [String]) -> Void>(kind: .migrations)
        let expected = ["audit", "sessions", "users"]
        var tables: [String] = []

        for migration in sut.values { migration(&tables) }

        #expect(tables.sorted() == expected)
    }

    @Test("A client's types are found typed as the protocol its macro requires")
    func events() {
        let sut = LinkerSet<any AnalyticsEvent.Type>(kind: .events)
        let expected = ["login", "logout", "purchase", "refund"]

        let actual = sut.values.map { $0.name }.sorted()

        #expect(actual == expected)
    }

    @Test("A client's types aren't found as Any.Type, the type their records don't hold")
    func eventsOnlyAsTheirProtocol() {
        let sut = LinkerSet<Any.Type>(kind: .events)

        let actual = sut.values

        #expect(actual.isEmpty)
    }

    @Test("Each client's kind holds only its own records")
    func kindsStayApart() {
        let expectedMigrationRecords = 3

        let migrationRecords = LinkerSet<Endpoint>(kind: .migrations).records
        let migrationsAsEndpoints = LinkerSet<Endpoint>(kind: .migrations).values
        let routesAsMigrations = LinkerSet<(inout [String]) -> Void>(kind: .routes).values

        #expect(migrationRecords.count == expectedMigrationRecords)
        #expect(migrationRecords.allSatisfy { $0.kind == .migrations })
        #expect(migrationsAsEndpoints.isEmpty)
        #expect(routesAsMigrations.isEmpty)
    }
}
#endif
