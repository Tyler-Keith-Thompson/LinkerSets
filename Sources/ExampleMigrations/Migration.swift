@_exported import LinkerSets

// A second client, declared the same way as ExampleRoutes' routes with a kind of its own, kept
// internal like theirs.

extension LinkerSetKind {
    /// Records of migrations, `"migr"`.
    static let migrations = LinkerSetKind(rawValue: 0x6D69_6772)
}

extension Migrations {
    /// Every migration the program declares, in the order ``LinkerSet/values`` gives them.
    public static var all: [(inout [String]) -> Void] {
        LinkerSet<(inout [String]) -> Void>(kind: .migrations).values
    }
}

/// Registers a static or free function `(inout [String]) -> Void` as a migration of a schema.
@attached(peer)
public macro Migration() = #externalMacro(module: "ExampleMigrationsMacros", type: "MigrationMacro")
