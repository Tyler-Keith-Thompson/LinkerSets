import LinkerSetsMacroSupport

/// `@LinkerSetEntry(kind:)` and `@LinkerSetEntry(kind:uniqueKey:)`: the library's own linker-set
/// macro, whose kind and optional unique key are its arguments.
///
/// The compiler finds a macro's type by the module the declaration names, so the type lives in
/// this plugin; its expansion is LinkerSetsMacroSupport's, which clients' plugins share.
public enum LinkerSetEntryMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) throws -> UInt32 {
        try kindArgument(of: attribute)
    }

    public static func uniqueKey(of declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) throws -> String? {
        try uniqueKeyArgument(of: attribute)
    }
}
