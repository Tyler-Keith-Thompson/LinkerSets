import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@LinkerSetEntry(kind:)`: a peer record, in the section LinkerSets owns, whose accessor
/// produces the declaration's value.
///
/// On a static property or global variable the value is the variable's; on a static or free
/// function it is the function itself, as a value of its function type.
public struct LinkerSetEntryMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let kind = try kindLiteral(of: node)
        #if canImport(SwiftSyntax600)
        let isMember = context.lexicalContext.first?.isTypeScope ?? false
        #else
        // A macro sees its lexical context from swift-syntax 600 on. Before it, `static` marks a
        // member (a global can't take it), and an instance member is left for the compiler to
        // refuse in the expansion.
        let isMember = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers.isStatic ?? false
        #endif
        let value = try value(of: declaration, isMember: isMember)
        let name = context.makeUniqueName("linkerSetRecord")
        let storage = isMember ? "private static let" : "private let"
        return [
            """
            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets")
            #elseif objectFormat(ELF)
            @section("linker_sets")
            #endif
            @used \(raw: storage) \(name): LinkerSets.LinkerSetRecord.Literal = (\(kind), 0, { outValue, type, _, _ in LinkerSets.LinkerSetRecord.__store(\(value), into: outValue, ifAsked: type) }, 0, 0)
            """,
        ]
    }

    /// The kind argument, as written: an integer literal from 1 through `UInt32.max`.
    private static func kindLiteral(of node: AttributeSyntax) throws -> IntegerLiteralExprSyntax {
        let argument = node.arguments?.as(LabeledExprListSyntax.self)?.first { $0.label?.text == "kind" }
        guard let argument, let literal = argument.expression.as(IntegerLiteralExprSyntax.self) else {
            throw DiagnosticsError(diagnostics: [Diagnostic(node: Syntax(node), message: LinkerSetEntryDiagnostic.kindNotLiteral)])
        }
        guard let kind = literal.unsignedValue else {
            throw DiagnosticsError(diagnostics: [Diagnostic(node: Syntax(literal), message: LinkerSetEntryDiagnostic.kindOutOfRange)])
        }
        guard kind != 0 else {
            throw DiagnosticsError(diagnostics: [Diagnostic(node: Syntax(literal), message: LinkerSetEntryDiagnostic.kindZero)])
        }
        return literal.trimmed
    }

    /// The expression the record's accessor stores: the variable, or the function as a value of
    /// its function type, named with its argument labels so an overload can't be mistaken for it.
    private static func value(of declaration: some DeclSyntaxProtocol, isMember: Bool) throws -> ExprSyntax {
        if let variable = declaration.as(VariableDeclSyntax.self) {
            try requireStatic(variable.modifiers, of: variable, isMember: isMember)
            // The compiler itself refuses a peer macro on a declaration of several variables, so one
            // binding is left: refuse it when it isn't a single name.
            guard let pattern = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self) else {
                throw DiagnosticsError(diagnostics: [Diagnostic(node: Syntax(variable), message: LinkerSetEntryDiagnostic.unnamedVariable)])
            }
            return isMember ? "Self.\(pattern.identifier.trimmed)" : "\(pattern.identifier.trimmed)"
        }
        if let function = declaration.as(FunctionDeclSyntax.self) {
            try requireStatic(function.modifiers, of: function, isMember: isMember)
            guard function.genericParameterClause == nil else {
                throw DiagnosticsError(diagnostics: [Diagnostic(node: Syntax(function), message: LinkerSetEntryDiagnostic.genericFunction)])
            }
            let reference: ExprSyntax = isMember ? "Self.\(raw: function.compoundName)" : "\(raw: function.compoundName)"
            return "\(reference) as \(function.functionType)"
        }
        throw DiagnosticsError(diagnostics: [Diagnostic(node: Syntax(declaration), message: LinkerSetEntryDiagnostic.unsupportedDeclaration)])
    }

    private static func requireStatic(_ modifiers: DeclModifierListSyntax, of declaration: some SyntaxProtocol, isMember: Bool) throws {
        guard isMember else { return }
        guard modifiers.isStatic else {
            throw DiagnosticsError(diagnostics: [Diagnostic(node: Syntax(declaration), message: LinkerSetEntryDiagnostic.instanceMember)])
        }
    }
}

extension Syntax {
    /// Whether a declaration directly inside this one is a member of a type.
    fileprivate var isTypeScope: Bool {
        `is`(StructDeclSyntax.self) || `is`(EnumDeclSyntax.self) || `is`(ClassDeclSyntax.self)
            || `is`(ActorDeclSyntax.self) || `is`(ExtensionDeclSyntax.self) || `is`(ProtocolDeclSyntax.self)
    }
}

extension DeclModifierListSyntax {
    /// Whether the list holds `static` or `class`.
    fileprivate var isStatic: Bool {
        contains { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }
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

extension FunctionDeclSyntax {
    /// The function's name with its argument labels, `name(label:_:)`, or the bare name when it
    /// takes no parameters.
    fileprivate var compoundName: String {
        let parameters = signature.parameterClause.parameters
        guard !parameters.isEmpty else { return name.text }
        return name.text + "(" + parameters.map { "\($0.firstName.text):" }.joined() + ")"
    }

    /// The function's type, `(Int, inout String) async throws -> Bool`.
    fileprivate var functionType: TypeSyntax {
        let parameters = signature.parameterClause.parameters
            .map { $0.type.trimmedDescription + ($0.ellipsis == nil ? "" : "...") }
            .joined(separator: ", ")
        #if canImport(SwiftSyntax600)
        // Typed throws, `throws(E)`, arrived with swift-syntax 600's throws clause.
        let throwing = signature.effectSpecifiers?.throwsClause?.trimmedDescription
        #else
        let throwing = signature.effectSpecifiers?.throwsSpecifier?.text
        #endif
        let effects = [signature.effectSpecifiers?.asyncSpecifier?.text, throwing]
            .compactMap { $0 }
            .map { $0 + " " }
            .joined()
        let result = signature.returnClause?.type.trimmedDescription ?? "Void"
        return "(\(raw: parameters)) \(raw: effects)-> \(raw: result)"
    }
}
