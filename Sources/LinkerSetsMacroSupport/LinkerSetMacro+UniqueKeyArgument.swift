import SwiftParser
import SwiftSyntax

extension LinkerSetMacro {
    /// The attribute's `uniqueKey:` argument, a string literal, or `nil` when it has none.
    ///
    /// For a macro whose users write each declaration's key, as `@LinkerSetEntry(kind:uniqueKey:)`
    /// does, rather than one that derives it from the declaration. Return it from
    /// ``uniqueKey(of:attribute:)``.
    ///
    /// - Parameter attribute: The attribute as written, such as
    ///   `@LinkerSetEntry(kind: 0x726F_7574, uniqueKey: "/home")`.
    /// - Returns: The literal's value, escapes resolved, or `nil` without the argument.
    /// - Throws: A diagnostic at the argument when it isn't a string literal, or holds an
    ///   interpolation, which the macro can't read at compile time.
    public static func uniqueKeyArgument(of attribute: AttributeSyntax) throws -> String? {
        let macroName = "@" + attribute.attributeName.trimmedDescription
        let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) ?? []
        guard let argument = arguments.first(where: { $0.label?.text == "uniqueKey" }) else { return nil }
        // representedLiteralValue is nil for a literal with an interpolation.
        guard let key = argument.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue else {
            throw LinkerSetMacroDiagnostic(.uniqueKeyNotLiteral, macroName: macroName, at: argument.expression).error
        }
        return key
    }
}
