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
/// The expansion is one peer, `#linkerSetRecord(kind:storing:)` (``LinkerSetRecordMacro``), which
/// the LinkerSets module declares and which expands in turn to a private `@used` declaration,
/// placed with `@section` in the section LinkerSets owns, whose accessor produces the declaration's
/// value:
///
/// - a static property's or a global variable's value;
/// - a static or free function, as a value of its function type;
/// - a struct, enum, class or actor, as its metatype: `any P.Type` when
///   ``requiredConformance(of:)`` names a protocol `P`, which the type must then conform to or the
///   expansion doesn't compile, and `Any.Type` otherwise.
///
/// A function isolated to the main actor, by its own `@MainActor` or its type's or extension's,
/// is stored as its isolated type (`@MainActor () -> Void`), read with
/// `LinkerSet<@MainActor () -> Void>` and called on the main actor. A property isolated to the
/// main actor is refused, since the record's nonisolated accessor can't read it: one marked
/// `@MainActor`, or a `var` of a `@MainActor` type. Only a written `@MainActor` is seen. A custom
/// global actor's attribute, and isolation a type inherits from a protocol it conforms to, can't
/// be seen in the syntax, so a member isolated that way fails to compile inside the expansion.
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

    /// The name of the freestanding macro the record's peer calls, without the `#`:
    /// `linkerSetRecord`, which the LinkerSets module declares, unless the client declares one of
    /// its own.
    ///
    /// A client whose modules depend on LinkerSetsRuntime rather than LinkerSets, so that
    /// LinkerSets' plugin and swift-syntax stay out of their builds, declares its own record macro,
    /// `#routeRecord(kind:storing:)` say, implemented by a type in its plugin that calls
    /// ``LinkerSetRecordMacro``'s expansion, and returns its name here. The name must differ from
    /// `linkerSetRecord`: a module that imports both declarations couldn't tell them apart.
    static var recordMacroName: String { get }
}

extension LinkerSetMacro {
    /// No required protocol: a type's record holds `Any.Type`.
    public static func requiredConformance(of attribute: AttributeSyntax) throws -> TypeSyntax? {
        nil
    }

    /// `linkerSetRecord`: LinkerSets' own record macro.
    public static var recordMacroName: String { "linkerSetRecord" }

    /// The record that `declaration` becomes, as a peer:
    /// ``recordPeers(of:providingPeersOf:in:)``.
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try recordPeers(of: node, providingPeersOf: declaration, in: context)
    }

    /// The record that `declaration` becomes, as a peer, for a macro that writes its own
    /// `expansion` and calls this from it: to add a condition first, or beside another role, such
    /// as an extension that adds a conformance.
    ///
    /// - Parameters:
    ///   - node: The attribute being expanded.
    ///   - declaration: The declaration it's attached to.
    ///   - context: The expansion's context.
    /// - Returns: The record's declaration, a call of ``LinkerSetRecordMacro`` by
    ///   ``recordMacroName`` (`#linkerSetRecord(kind: 0x726F7574, storing: Self.home)`), whose own
    ///   expansion writes one declaration per object format.
    /// - Throws: The ``LinkerSetMacroDiagnostic/error`` of a refused kind or declaration, and
    ///   whatever ``kind(of:)`` or ``requiredConformance(of:)`` throws.
    public static func recordPeers(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let macroName = "@" + node.attributeName.trimmedDescription
        let kind = try kind(of: node)
        guard kind != 0 else { throw LinkerSetMacroDiagnostic(.kindZero, macroName: macroName, at: node).error }
        let site = RecordSite(declaration, in: context)
        let value: ExprSyntax
        switch try recordValue(of: declaration, at: site, attribute: node, macroName: macroName) {
        case .value(let expression): value = expression
        case .refused(let refusal): throw refusal.error
        }
        // The record itself is LinkerSets' own macro's expansion, so a client's expansion stays one
        // line however many object formats LinkerSets writes.
        let call: DeclSyntax = "#\(raw: recordMacroName)(kind: \(raw: kind.hexadecimalLiteral), storing: \(value))"
        guard !site.isMember else { return [call] }
        // At file scope the compiler drops the globals a freestanding macro declares inside a peer's
        // expansion, so a global's record is a member of a private enum of its own instead.
        return ["private enum \(context.makeUniqueName("linkerSetRecord")) { \(call) }"]
    }

    /// Why `declaration` can't hold a record, or `nil` when it can: the checks
    /// ``recordPeers(of:providingPeersOf:in:)`` makes of the declaration and of where it sits,
    /// without writing anything.
    ///
    /// A client that wants something other than the error for one of them, such as a note and no
    /// record for a generic type, asks this first, reports the refusal its own way and returns no
    /// peers. The kind isn't checked here; ``recordPeers(of:providingPeersOf:in:)`` still checks
    /// it.
    ///
    /// Where the declaration sits (in a function's body, a protocol or a generic type) is seen
    /// from swift-syntax 600 on. Before it, those three are left for the compiler to refuse in the
    /// expansion, and this returns `nil` for them.
    ///
    /// - Parameters:
    ///   - node: The attribute being expanded.
    ///   - declaration: The declaration it's attached to.
    ///   - context: The expansion's context.
    /// - Returns: The refusal, with its ``LinkerSetMacroDiagnostic/reason`` and the node it points
    ///   at, or `nil`.
    /// - Throws: Whatever ``requiredConformance(of:)`` throws.
    public static func refusal(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> LinkerSetMacroDiagnostic? {
        let macroName = "@" + node.attributeName.trimmedDescription
        let site = RecordSite(declaration, in: context)
        guard case .refused(let refusal) = try recordValue(of: declaration, at: site, attribute: node, macroName: macroName) else { return nil }
        return refusal
    }

    /// The expression the record's accessor stores, or why there is none: the scope first, then
    /// the declaration itself.
    ///
    /// A refusal is a value rather than a thrown error, so ``refusal(of:providingPeersOf:in:)`` can
    /// return it, while a client's own error from ``requiredConformance(of:)`` still propagates.
    private static func recordValue(of declaration: some DeclSyntaxProtocol, at site: RecordSite, attribute: AttributeSyntax, macroName: String) throws -> RecordValue {
        if let reason = site.scopeRefusal {
            return .refused(LinkerSetMacroDiagnostic(reason, macroName: macroName, at: declaration))
        }
        return try value(of: declaration, isMember: site.isMember, enclosingIsMainActor: site.enclosingIsMainActor, attribute: attribute, macroName: macroName)
    }

    /// The expression the record's accessor stores: the variable; the function as a value of its
    /// function type, named with its argument labels so an overload can't be mistaken for it; or
    /// the type's metatype, as the existential of its required protocol.
    ///
    /// A record's accessor is a nonisolated C function. A function isolated to the main actor (by
    /// its own `@MainActor`, or its type's or extension's, unless it is `nonisolated`) is stored as
    /// its isolated type, `@MainActor () -> Void`, which a nonisolated accessor may hold but not
    /// call. A property isolated to the main actor can't be read there at all, so it is refused:
    /// one marked `@MainActor` itself, or a `var` of a `@MainActor` type. A `let` of a
    /// `@MainActor` type is read as it is, since a stored `let` of a Sendable type is nonisolated.
    private static func value(of declaration: some DeclSyntaxProtocol, isMember: Bool, enclosingIsMainActor: Bool, attribute: AttributeSyntax, macroName: String) throws -> RecordValue {
        func refused(_ reason: LinkerSetMacroDiagnostic.Reason, at node: some SyntaxProtocol) -> RecordValue {
            .refused(LinkerSetMacroDiagnostic(reason, macroName: macroName, at: node))
        }
        if let variable = declaration.as(VariableDeclSyntax.self) {
            if isMember && !variable.modifiers.isStatic { return refused(.instanceMember, at: variable) }
            let inheritsMainActor = enclosingIsMainActor && !variable.modifiers.isNonisolated
                && variable.bindingSpecifier.tokenKind == .keyword(.var)
            if variable.attributes.isMainActor || inheritsMainActor { return refused(.isolatedProperty, at: variable) }
            // The compiler itself refuses a peer macro on a declaration of several variables, so one
            // binding is left: refuse it when it isn't a single name.
            guard let pattern = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self) else {
                return refused(.unnamedVariable, at: variable)
            }
            return .value(isMember ? "Self.\(pattern.identifier.trimmed)" : "\(pattern.identifier.trimmed)")
        }
        if let function = declaration.as(FunctionDeclSyntax.self) {
            if isMember && !function.modifiers.isStatic { return refused(.instanceMember, at: function) }
            if let generics = function.genericParameterClause { return refused(.genericFunction, at: generics) }
            let reference: ExprSyntax = isMember ? "Self.\(raw: function.compoundName)" : "\(raw: function.compoundName)"
            let isMainActor = function.attributes.isMainActor || (enclosingIsMainActor && !function.modifiers.isNonisolated)
            return .value(isMainActor ? "\(reference) as @MainActor \(function.functionType)" : "\(reference) as \(function.functionType)")
        }
        if let type = NominalType(declaration) {
            if let generics = type.genericParameterClause { return refused(.genericType, at: generics) }
            let reference: ExprSyntax = isMember ? "Self.\(type.name).self" : "\(type.name).self"
            // The coercion is the conformance check: a type that doesn't conform fails to compile
            // here, at the attribute.
            guard let conformance = try requiredConformance(of: attribute) else { return .value("\(reference) as Any.Type") }
            return .value("\(reference) as any (\(conformance.trimmed)).Type")
        }
        return refused(.unsupportedDeclaration, at: declaration)
    }
}

/// What a declaration's record stores, or why it can't have one.
private enum RecordValue {
    case value(ExprSyntax)
    case refused(LinkerSetMacroDiagnostic)
}

/// Where a declaration sits, as far as the macro can see it.
private struct RecordSite {
    /// Whether the declaration is a member of a type (or extension), so the record is a static
    /// member beside it.
    let isMember: Bool
    /// Whether the enclosing type or extension is marked `@MainActor`, which a member takes unless
    /// it says otherwise.
    let enclosingIsMainActor: Bool
    /// Why no record can be declared here, or `nil`.
    let scopeRefusal: LinkerSetMacroDiagnostic.Reason?

    init(_ declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) {
        #if canImport(SwiftSyntax600)
        let lexicalContext = context.lexicalContext  // innermost scope first
        isMember = lexicalContext.first?.isTypeScope ?? false
        enclosingIsMainActor = lexicalContext.first?.asProtocol(WithAttributesSyntax.self)?.attributes.isMainActor ?? false
        // A record is a global, and a local has no address until its scope runs; a requirement
        // has no value of its own; a record holds one concrete value, not one per specialization.
        if lexicalContext.contains(where: { !$0.isTypeScope }) {
            scopeRefusal = .localDeclaration
        } else if lexicalContext.first?.is(ProtocolDeclSyntax.self) == true {
            scopeRefusal = .protocolRequirement
        } else if lexicalContext.contains(where: { NominalType($0)?.isGeneric == true }) {
            scopeRefusal = .memberOfGenericType
        } else {
            scopeRefusal = nil
        }
        #else
        // A macro sees its lexical context from swift-syntax 600 on. Before it, `static` marks a
        // member (a global can't take it), the enclosing type's isolation can't be seen, and a
        // local declaration or a member of a generic type is left for the compiler to refuse in
        // the expansion.
        isMember = declaration.asProtocol(WithModifiersSyntax.self)?.modifiers.isStatic ?? false
        enclosingIsMainActor = false
        scopeRefusal = nil
        #endif
    }
}

extension UInt32 {
    /// The value as a Swift hexadecimal literal, `0x726F7574`.
    var hexadecimalLiteral: String {
        let digits = String(self, radix: 16, uppercase: true)
        return "0x" + String(repeating: "0", count: 8 - digits.count) + digits
    }
}

/// A struct, enum, class or actor declaration, which a record can hold as a metatype.
private struct NominalType {
    let name: TokenSyntax
    /// The type's generic parameters, `<T>`, or `nil` for a type that has none.
    let genericParameterClause: GenericParameterClauseSyntax?

    var isGeneric: Bool { genericParameterClause != nil }

    /// The type `declaration` declares, or `nil` when it declares none of the four.
    init?(_ declaration: some SyntaxProtocol) {
        if let decl = declaration.as(StructDeclSyntax.self) {
            (name, genericParameterClause) = (decl.name.trimmed, decl.genericParameterClause)
        } else if let decl = declaration.as(EnumDeclSyntax.self) {
            (name, genericParameterClause) = (decl.name.trimmed, decl.genericParameterClause)
        } else if let decl = declaration.as(ClassDeclSyntax.self) {
            (name, genericParameterClause) = (decl.name.trimmed, decl.genericParameterClause)
        } else if let decl = declaration.as(ActorDeclSyntax.self) {
            (name, genericParameterClause) = (decl.name.trimmed, decl.genericParameterClause)
        } else {
            return nil
        }
    }
}

extension Syntax {
    /// Whether a declaration directly inside this one is a member of a type.
    var isTypeScope: Bool {
        `is`(StructDeclSyntax.self) || `is`(EnumDeclSyntax.self) || `is`(ClassDeclSyntax.self)
            || `is`(ActorDeclSyntax.self) || `is`(ExtensionDeclSyntax.self) || `is`(ProtocolDeclSyntax.self)
    }
}

extension DeclModifierListSyntax {
    /// Whether the list holds `static` or `class`.
    fileprivate var isStatic: Bool {
        contains { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }
    }

    /// Whether the list holds `nonisolated`.
    fileprivate var isNonisolated: Bool {
        contains { $0.name.tokenKind == .keyword(.nonisolated) }
    }
}

extension AttributeListSyntax {
    /// Whether the list holds `@MainActor`. A custom global actor's attribute can't be told from
    /// any other attribute by its syntax, so only the main actor's is recognized.
    fileprivate var isMainActor: Bool {
        contains { element in
            guard case .attribute(let attribute) = element else { return false }
            let name = attribute.attributeName.trimmedDescription
            return name == "MainActor" || name == "_Concurrency.MainActor"
        }
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
