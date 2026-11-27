// Records from several statically linked modules, found in a test binary the linker dead-strips
// (-dead_strip on Mach-O, --gc-sections on ELF), in debug and release builds alike. Not
// speed-reliant: these sit in Performance/ because that target is the one release builds run.
// Each test is self-contained and fails if the linker dropped a module's records.

#if objectFormat(MachO) || objectFormat(ELF)
import ExampleEvents
import ExampleMigrations
import ExampleRoutes
import LinkerSets
import Testing

@Suite("Linking: records survive dead stripping")
struct LinkingTests {
    @Test("Routes, declared as static properties in ExampleRoutes, are found")
    func routesModule() {
        let sut = LinkerSet<Endpoint>(kind: .routes)
        let expected = ["/", "/settings"]

        let actual = sut.values.map(\.path).sorted()

        #expect(actual == expected)
    }

    @Test("Migrations, declared as static and free functions in ExampleMigrations, are found")
    func migrationsModule() {
        let sut = LinkerSet<(inout [String]) -> Void>(kind: .migrations)
        let expected = ["audit", "sessions", "users"]
        var tables: [String] = []

        for migration in sut.values { migration(&tables) }

        #expect(tables.sorted() == expected)
    }

    @Test("Events, declared as types in ExampleEvents, are found")
    func eventsModule() {
        let sut = LinkerSet<any AnalyticsEvent.Type>(kind: .events)
        let expected = ["login", "logout", "purchase", "refund"]

        let actual = sut.values.map { $0.name }.sorted()

        #expect(actual == expected)
    }

    // This target links ExamplePlugins but never imports it, and nothing in the program names its
    // types, so its records are the only reason the module is linked at all.
    @Test("Plug-ins in a module no code references are found by their kind alone")
    func unreferencedModule() {
        let sut = LinkerSet<Any.Type>(kind: LinkerSetKind(rawValue: 0x706C_7567))
        let expected = ["ExportPlugin", "ImportPlugin"]

        let actual = sut.values.map { String(describing: $0) }.sorted()

        #expect(actual == expected)
    }
}
#endif
