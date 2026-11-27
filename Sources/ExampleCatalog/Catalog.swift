import LinkerSetsRuntime

// A module that only reads records, so it depends on LinkerSetsRuntime alone and builds no macros
// or swift-syntax. It reads two sets it didn't write: ExamplePlugins' plug-in types, written by
// @LinkerSetEntry, and ExampleMigrations' migrations, written by its own @Migration macro. Each is
// read by its kind's number and a value type this module can spell without importing the writer.

/// What the program's other modules registered, read without importing them.
public enum Catalog {
    /// The names of the plug-in types registered with kind `"plug"`, sorted.
    public static var pluginNames: [String] {
        LinkerSet<Any.Type>(kind: LinkerSetKind(rawValue: 0x706C_7567)).values.map { "\($0)" }.sorted()
    }

    /// The tables the migrations registered with kind `"migr"` create, applied to an empty schema,
    /// sorted.
    public static var migratedTables: [String] {
        var tables: [String] = []
        for migration in LinkerSet<(inout [String]) -> Void>(kind: LinkerSetKind(rawValue: 0x6D69_6772)).values {
            migration(&tables)
        }
        return tables.sorted()
    }
}
