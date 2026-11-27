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
/// owns, whose accessor produces the declaration's value:
///
/// - a static property's or a global variable's value;
/// - a static or free function, as a value of its function type;
/// - a struct, enum, class or actor, as its metatype: `any P.Type` when
///   ``requiredConformance(of:)`` names a protocol `P`, which the type must then conform to or the
///   expansion doesn't compile, and `Any.Type` otherwise.
///
/// It diagnoses anything else, each with a message of its own: generic functions and types,
/// members of generic types, instance members, protocol requirements, declarations inside a
/// function, closure or accessor, and a kind that isn't a 32-bit literal other than 0.
///
/// Before swift-syntax 600 a macro can't see its lexical context. There a type it registers must
/// be declared at file scope, and the compiler, not the macro, refuses a local declaration or a
/// member of a generic type, with an error in the expansion.
public protocol LinkerSetMacro: PeerMacro {
    /// The kind of the record that `attribute` declares, from 1 through `UInt32.max`.
    ///
    /// - Parameter attribute: The attribute being expanded, as written.
    /// - Returns: The kind to tag the record with.
    /// - Throws: A diagnostic when the attribute doesn't give a kind the macro can use.
    static func kind(of attribute: AttributeSyntax) throws -> UInt32

    /// The protocol a type that `attribute` registers must conform to, such as `Event`, or `nil`
    /// for none.
    ///
    /// A type's record holds `any P.Type` for the protocol `P` returned here, so a client reads
    /// `LinkerSet<any P.Type>` without casting. With `nil` it holds `Any.Type`. Properties and
    /// functions ignore it.
    ///
    /// - Parameter attribute: The attribute being expanded, as written.
    /// - Returns: The protocol's name, or `nil`.
    /// - Throws: A diagnostic when the attribute doesn't give a protocol the macro can use.
    static func requiredConformance(of attribute: AttributeSyntax) throws -> TypeSyntax?
}

extension LinkerSetMacro {
    /// No required protocol: a type's record holds `Any.Type`.
    public static func requiredConformance(of attribute: AttributeSyntax) throws -> TypeSyntax? {
        nil
    }

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
        try requireRecordableScope(context.lexicalContext, of: declaration, macroName: macroName)
        let isMember = context.lexicalContext.first?.isTypeScope ?? false
        #else
        // A macro sees its lexical context from swift-syntax 600 on. Before it, `static` marks a
        // member (a global can't take it), and an instance member, a local declaration and a
        // member of a generic type are left for the compiler to refuse in the expansion.
        let isMember = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers.isStatic ?? false
        #endif
        let value = try value(of: declaration, isMember: isMember, attribute: node, macroName: macroName)
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

    #if canImport(SwiftSyntax600)
    /// Refuses a declaration whose scope a record can't reach: inside a function, closure or
    /// accessor (a record is a global, and a local has no address until its scope runs), in a
    /// protocol (a requirement has no value of its own), or in a generic type (a record holds
    /// one concrete value). `lexicalContext` runs from the innermost scope out.
    private static func requireRecordableScope(_ lexicalContext: [Syntax], of declaration: some DeclSyntaxProtocol, macroName: String) throws {
        if lexicalContext.contains(where: { !$0.isTypeScope }) {
            throw LinkerSetMacroDiagnostic.error(.localDeclaration, at: declaration, macroName: macroName)
        }
        if lexicalContext.first?.is(ProtocolDeclSyntax.self) == true {
            throw LinkerSetMacroDiagnostic.error(.protocolRequirement, at: declaration, macroName: macroName)
        }
        if lexicalContext.contains(where: { NominalType($0)?.isGeneric == true }) {
            throw LinkerSetMacroDiagnostic.error(.memberOfGenericType, at: declaration, macroName: macroName)
        }
    }
    #endif

    /// The expression the record's accessor stores: the variable; the function as a value of its
    /// function type, named with its argument labels so an overload can't be mistaken for it; or
    /// the type's metatype, as the existential of its required protocol.
    private static func value(of declaration: some DeclSyntaxProtocol, isMember: Bool, attribute: AttributeSyntax, macroName: String) throws -> ExprSyntax {
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
        if let type = NominalType(declaration) {
            guard !type.isGeneric else {
                throw LinkerSetMacroDiagnostic.error(.genericType, at: declaration, macroName: macroName)
            }
            let reference: ExprSyntax = isMember ? "Self.\(type.name).self" : "\(type.name).self"
            // The coercion is the conformance check: a type that doesn't conform fails to compile
            // here, at the attribute.
            guard let conformance = try requiredConformance(of: attribute) else { return "\(reference) as Any.Type" }
            return "\(reference) as any (\(conformance.trimmed)).Type"
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

/// A struct, enum, class or actor declaration, which a record can hold as a metatype.
private struct NominalType {
    let name: TokenSyntax
    let isGeneric: Bool

    /// The type `declaration` declares, or `nil` when it declares none of the four.
    init?(_ declaration: some SyntaxProtocol) {
        if let decl = declaration.as(StructDeclSyntax.self) {
            (name, isGeneric) = (decl.name.trimmed, decl.genericParameterClause != nil)
        } else if let decl = declaration.as(EnumDeclSyntax.self) {
            (name, isGeneric) = (decl.name.trimmed, decl.genericParameterClause != nil)
        } else if let decl = declaration.as(ClassDeclSyntax.self) {
            (name, isGeneric) = (decl.name.trimmed, decl.genericParameterClause != nil)
        } else if let decl = declaration.as(ActorDeclSyntax.self) {
            (name, isGeneric) = (decl.name.trimmed, decl.genericParameterClause != nil)
        } else {
            return nil
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
