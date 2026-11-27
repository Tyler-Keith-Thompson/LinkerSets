import LinkerSetsMacroSupport

/// `#linkerSetRecord(kind:storing:)`: the record every linker-set macro's expansion calls.
///
/// The compiler finds a macro's type by the module the declaration names, `LinkerSetsMacros`, so
/// this plugin holds a type of that name; the expansion is LinkerSetsMacroSupport's, where a
/// client's expansion tests can reach it too.
public enum LinkerSetRecordMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try LinkerSetsMacroSupport.LinkerSetRecordMacro.expansion(of: node, in: context)
    }
}
