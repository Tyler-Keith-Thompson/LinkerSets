import LinkerSetsMacroSupport
import SwiftCompilerPlugin

// A client plugin that keeps LinkerSets out of its users' builds. Its entry macro takes the kind
// as an argument, as @LinkerSetEntry does, and its expansion calls the plugin's own record macro,
// #discoverableRecord, rather than LinkerSets' #linkerSetRecord, so the modules that use it depend
// on LinkerSetsRuntime and ExampleDiscovery, not on LinkerSets' plugin and swift-syntax.

@main
struct ExampleDiscoveryMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [DiscoverableMacro.self, DiscoverableRecordMacro.self]
}

/// `@Discoverable(kind:)`: a record of the kind its argument gives.
public enum DiscoverableMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) throws -> UInt32 {
        try kindArgument(of: attribute)
    }

    public static var recordMacroName: String { "discoverableRecord" }
}

/// `#discoverableRecord(kind:storing:)`: the record `@Discoverable` writes, LinkerSetsMacroSupport's
/// expansion under a name and module of this client's own.
public enum DiscoverableRecordMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try LinkerSetRecordMacro.expansion(of: node, in: context)
    }
}
