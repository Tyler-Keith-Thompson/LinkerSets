import LinkerSetsMacroSupport
import SwiftCompilerPlugin

// The second client's plugin, the same shape as ExampleRoutesMacros with its own kind.

@main
struct ExampleMigrationsMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [MigrationMacro.self]
}

/// `@Migration`: registers a migration, a record of kind `"migr"`.
public enum MigrationMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6D69_6772 }
}
