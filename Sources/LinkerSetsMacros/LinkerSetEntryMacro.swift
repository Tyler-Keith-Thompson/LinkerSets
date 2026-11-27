import LinkerSetsMacroSupport

/// `@LinkerSetEntry(kind:)`: the library's own linker-set macro, whose kind is its argument.
///
/// The compiler finds a macro's type by the module the declaration names, so the type lives in
/// this plugin; its expansion is LinkerSetsMacroSupport's, which clients' plugins share.
public enum LinkerSetEntryMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) throws -> UInt32 {
        try kindArgument(of: attribute)
    }
}
