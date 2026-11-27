@_exported import SwiftSyntax
import SwiftSyntaxBuilder
@_exported import SwiftSyntaxMacros

/// A macro that turns the declaration it's attached to into a linker-set record of one kind.
///
/// A client declares its own macro by conforming a type in its compiler plugin and returning
/// its kind; the expansion is shared:
///
/// ```swift
/// import LinkerSetsMacroSupport
/// import SwiftCompilerPlugin
///
/// @main
/// struct RoutesPlugin: CompilerPlugin {
///     let providingMacros: [any Macro.Type] = [RouteMacro.self]
/// }
///
/// public enum RouteMacro: LinkerSetMacro {
///     public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x726F_7574 }
/// }
/// ```
///
/// The expansion is a private `@used` peer, placed with `@section` in the section LinkerSets
/// owns, whose accessor produces the variable's value, or the function itself as a value of its
/// function type. It applies to a static property, a global variable, a static function or a
/// free function, and diagnoses anything else.
public protocol LinkerSetMacro: PeerMacro {
    /// The kind of the record that `attribute` declares, from 1 through `UInt32.max`.
    ///
    /// - Parameter attribute: The attribute being expanded, as written.
    /// - Returns: The kind to tag the record with.
    /// - Throws: A diagnostic when the attribute doesn't give a kind the macro can use.
    static func kind(of attribute: AttributeSyntax) throws -> UInt32
}

extension LinkerSetMacro {
    /// The record that `declaration` becomes, as a peer.
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let macroName = "@" + node.attributeName.trimmedDescription
        let kind = try kind(of: node)
        guard kind != 0 else { throw LinkerSetMacroDiagnostic.error(.kindZero, at: node, macroName: macroName) }
        #if canImport(SwiftSyntax600)
        let isMember = context.lexicalContext.first?.isTypeScope ?? false
        #else
        // A macro sees its lexical context from swift-syntax 600 on. Before it, `static` marks a
        // member (a global can't take it), and an instance member is left for the compiler to
        // refuse in the expansion.
        let isMember = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers.isStatic ?? false
        #endif
        let value = try value(of: declaration, isMember: isMember, macroName: macroName)
        let name = context.makeUniqueName("linkerSetRecord")
        let storage = isMember ? "private static let" : "private let"
        return [
            """
            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets")
            #elseif objectFormat(ELF)
            @section("linker_sets")
            #endif
            @used \(raw: storage) \(name): LinkerSets.LinkerSetRecord.Literal = (\(raw: kind.hexadecimalLiteral), 0, { outValue, type, _, _ in LinkerSets.LinkerSetRecord.__store(\(value), into: outValue, ifAsked: type) }, 0, 0)
            """,
        ]
    }

    /// The expression the record's accessor stores: the variable, or the function as a value of
    /// its function type, named with its argument labels so an overload can't be mistaken for it.
    private static func value(of declaration: some DeclSyntaxProtocol, isMember: Bool, macroName: String) throws -> ExprSyntax {
        if let variable = declaration.as(VariableDeclSyntax.self) {
            try requireStatic(variable.modifiers, of: variable, isMember: isMember, macroName: macroName)
            // The compiler itself refuses a peer macro on a declaration of several variables, so one
            // binding is left: refuse it when it isn't a single name.
            guard let pattern = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self) else {
                throw LinkerSetMacroDiagnostic.error(.unnamedVariable, at: variable, macroName: macroName)
            }
            return isMember ? "Self.\(pattern.identifier.trimmed)" : "\(pattern.identifier.trimmed)"
        }
        if let function = declaration.as(FunctionDeclSyntax.self) {
            try requireStatic(function.modifiers, of: function, isMember: isMember, macroName: macroName)
            guard function.genericParameterClause == nil else {
                throw LinkerSetMacroDiagnostic.error(.genericFunction, at: function, macroName: macroName)
            }
            let reference: ExprSyntax = isMember ? "Self.\(raw: function.compoundName)" : "\(raw: function.compoundName)"
            return "\(reference) as \(function.functionType)"
        }
        throw LinkerSetMacroDiagnostic.error(.unsupportedDeclaration, at: declaration, macroName: macroName)
    }

    private static func requireStatic(_ modifiers: DeclModifierListSyntax, of declaration: some SyntaxProtocol, isMember: Bool, macroName: String) throws {
        guard isMember else { return }
        guard modifiers.isStatic else {
            throw LinkerSetMacroDiagnostic.error(.instanceMember, at: declaration, macroName: macroName)
        }
    }
}

extension UInt32 {
    /// The value as a Swift hexadecimal literal, `0x726F7574`.
    fileprivate var hexadecimalLiteral: String {
        let digits = String(self, radix: 16, uppercase: true)
        return "0x" + String(repeating: "0", count: 8 - digits.count) + digits
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
