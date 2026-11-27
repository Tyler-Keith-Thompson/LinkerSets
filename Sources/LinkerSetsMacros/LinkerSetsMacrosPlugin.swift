import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The compiler plugin that holds LinkerSets' macros.
@main
struct LinkerSetsMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        LinkerSetEntryMacro.self,
    ]
}
