import LinkerSetsMacroSupport
import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The compiler plugin that holds LinkerSets' own macro; the expansion lives in
/// LinkerSetsMacroSupport, which clients' plugins share.
@main
struct LinkerSetsMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        LinkerSetEntryMacro.self,
    ]
}
