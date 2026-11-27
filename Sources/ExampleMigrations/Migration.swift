@_exported import LinkerSets

// A second client, declared the same way as ExampleRoutes' routes with a kind of its own.

extension LinkerSetKind {
    /// Records of migrations, `"migr"`.
    public static let migrations = LinkerSetKind(rawValue: 0x6D69_6772)
}

/// Registers a static or free function `(inout [String]) -> Void` as a migration of a schema.
@attached(peer)
public macro Migration() = #externalMacro(module: "ExampleMigrationsMacros", type: "MigrationMacro")
