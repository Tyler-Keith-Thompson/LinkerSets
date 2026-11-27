extension LinkerSetMacro {
    /// The attribute's `kind:` argument: an integer literal from 1 through `UInt32.max`.
    ///
    /// For a macro that takes its kind as an argument, as `@LinkerSetEntry(kind:)` does, rather
    /// than fixing one.
    ///
    /// - Parameter attribute: The attribute as written, such as `@LinkerSetEntry(kind: 0x726F_7574)`.
    /// - Returns: The literal's value.
    /// - Throws: A diagnostic when the argument is missing, isn't an integer literal, doesn't fit in
    ///   32 bits or is 0.
    public static func kindArgument(of attribute: AttributeSyntax) throws -> UInt32 {
        let macroName = "@" + attribute.attributeName.trimmedDescription
        let argument = attribute.arguments?.as(LabeledExprListSyntax.self)?.first { $0.label?.text == "kind" }
        guard let argument, let literal = argument.expression.as(IntegerLiteralExprSyntax.self) else {
            throw LinkerSetMacroDiagnostic(.kindNotLiteral, macroName: macroName, at: attribute).error
        }
        guard let kind = literal.unsignedValue else {
            throw LinkerSetMacroDiagnostic(.kindOutOfRange, macroName: macroName, at: literal).error
        }
        // The shared expansion refuses kind 0 at the attribute; here it can point at the literal.
        guard kind != 0 else {
            throw LinkerSetMacroDiagnostic(.kindZero, macroName: macroName, at: literal).error
        }
        return kind
    }
}

extension IntegerLiteralExprSyntax {
    /// The literal's value as a `UInt32`, or `nil` when it doesn't fit.
    fileprivate var unsignedValue: UInt32? {
        let digits = String(literal.text.filter { $0 != "_" })
        let prefixes: [(String, Int)] = [("0x", 16), ("0o", 8), ("0b", 2)]
        for (prefix, radix) in prefixes where digits.hasPrefix(prefix) {
            return UInt32(digits.dropFirst(2), radix: radix)
        }
        return UInt32(digits)
    }
}
