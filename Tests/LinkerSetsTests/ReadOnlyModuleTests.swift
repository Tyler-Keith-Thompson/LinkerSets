// A module that depends on LinkerSetsRuntime alone (ExampleCatalog: no macros, no swift-syntax)
// reads records other modules wrote, with @LinkerSetEntry and with a client's own macro. Each test
// is self-contained.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
import ExampleCatalog
import ExampleMigrations
import ExamplePlugins
import Testing

@Suite("A module that only reads records")
struct ReadOnlyModuleTests {
    @Test("A read-only module finds the types another module registered with @LinkerSetEntry")
    func pluginsWrittenByLinkerSetEntry() {
        let expected = ["ExportPlugin", "ImportPlugin"]

        let actual = Catalog.pluginNames

        #expect(actual == expected)
    }

    @Test("A read-only module finds the functions another module registered with its own macro")
    func migrationsWrittenByAClientMacro() {
        let expected = ["audit", "sessions", "users"]

        let actual = Catalog.migratedTables

        #expect(actual == expected)
    }
}
#endif
