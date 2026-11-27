// Clients in one binary, each with its own kind and macro (ExampleRoutes' @Route,
// ExampleMigrations' @Migration, ExampleEvents' @Event), find their own records and never each
// other's. Each test is self-contained.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
import ExampleEvents
import ExampleMigrations
import ExampleRoutes
import LinkerSets
import Testing

@Suite("Client kinds")
struct ClientKindsTests {
    @Test("A client's set holds the records its macro declared in its module")
    func routes() {
        let expected = ["/", "/settings"]

        let actual = Endpoints.all.map(\.path).sorted()

        #expect(actual == expected)
    }

    @Test("A second client's functions are found as values of their function type")
    func migrations() {
        let expected = ["audit", "sessions", "users"]
        var tables: [String] = []

        for migration in Migrations.all { migration(&tables) }

        #expect(tables.sorted() == expected)
    }

    @Test("A client's types are found typed as the protocol its macro requires")
    func events() {
        let expected = ["login", "logout", "purchase", "refund"]

        let actual = AnalyticsEvents.all.map { $0.name }.sorted()

        #expect(actual == expected)
    }

    @Test("A client's types aren't found as Any.Type, the type their records don't hold")
    func eventsOnlyAsTheirProtocol() {
        let events = LinkerSetKind(rawValue: 0x6576_6E74)  // "evnt", ExampleEvents' kind
        let sut = LinkerSet<Any.Type>(kind: events)

        let actual = sut.values

        #expect(actual.isEmpty)
    }

    @Test("Each client's kind holds only its own records")
    func kindsStayApart() {
        let migrations = LinkerSetKind(rawValue: 0x6D69_6772)  // "migr", ExampleMigrations' kind
        let routes = LinkerSetKind(rawValue: 0x726F_7574)  // "rout", ExampleRoutes' kind
        let expectedMigrationRecords = 3

        let migrationRecords = LinkerSet<Endpoint>(kind: migrations).records
        let migrationsAsEndpoints = LinkerSet<Endpoint>(kind: migrations).values
        let routesAsMigrations = LinkerSet<(inout [String]) -> Void>(kind: routes).values

        #expect(migrationRecords.count == expectedMigrationRecords)
        #expect(migrationRecords.allSatisfy { $0.kind == migrations })
        #expect(migrationsAsEndpoints.isEmpty)
        #expect(routesAsMigrations.isEmpty)
    }
}
#endif
