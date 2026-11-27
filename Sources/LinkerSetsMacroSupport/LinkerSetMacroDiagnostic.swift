@_exported import SwiftDiagnostics
import SwiftSyntax

/// Why a linker-set macro refuses a declaration or a kind, with the message the compiler shows,
/// naming the macro as it was written (`@Route`), and the node the message points at.
///
/// ``LinkerSetMacro/recordPeers(of:providingPeersOf:in:)`` throws it as an error.
/// ``LinkerSetMacro/refusal(of:providingPeersOf:in:)`` returns it, for a client that reports the
/// refusal its own way, such as a note and no record.
public struct LinkerSetMacroDiagnostic: DiagnosticMessage {
    /// The ways a declaration or a kind can be refused.
    public enum Reason: String, Hashable, Sendable {
        /// The kind isn't an integer literal.
        case kindNotLiteral
        /// The kind doesn't fit in 32 bits.
        case kindOutOfRange
        /// The kind is 0, which marks an empty slot.
        case kindZero
        /// The declaration is none a record can hold, such as an initializer or a typealias.
        case unsupportedDeclaration
        /// The declaration is an instance member, which has no value without an instance.
        case instanceMember
        /// The variable binds a tuple pattern rather than one name.
        case unnamedVariable
        /// The function is generic.
        case genericFunction
        /// The type is generic.
        case genericType
        /// The declaration is a member of a generic type.
        case memberOfGenericType
        /// The declaration is a protocol's requirement.
        case protocolRequirement
        /// The declaration is inside a function, closure or accessor.
        case localDeclaration
        /// The property is isolated to the main actor, out of the record's accessor's reach.
        case isolatedProperty
        /// `#linkerSetRecord` was called without the `storing:` expression its record holds.
        case missingValue
        /// The macro's ``LinkerSetMacro/uniqueKey(of:attribute:)`` gave an empty key.
        case emptyUniqueKey
        /// The `uniqueKey:` argument isn't a string literal, or holds an interpolation.
        case uniqueKeyNotLiteral
        /// The declaration has a unique key but sits in a private or fileprivate type, where the
        /// symbol that checks the key would be local to its file and never compared.
        case uniqueKeyInPrivateScope
    }

    /// Why the declaration or kind is refused.
    public let reason: Reason
    /// The attribute as written, such as `@Route`.
    public let macroName: String
    /// The node the message points at: the declaration, or the attribute for a kind.
    public let node: Syntax

    /// The refusal of `reason`, reported at `node` under `macroName`.
    ///
    /// - Parameters:
    ///   - reason: Why the declaration or kind is refused.
    ///   - macroName: The attribute as written, such as `@Route`.
    ///   - node: The node the message points at.
    public init(_ reason: Reason, macroName: String, at node: some SyntaxProtocol) {
        self.reason = reason
        self.macroName = macroName
        self.node = Syntax(node)
    }

    public var message: String {
        switch reason {
        case .kindNotLiteral:
            "'\(macroName)' needs its kind as an integer literal, such as 'kind: 0x726F_7574'"
        case .kindOutOfRange:
            "'\(macroName)' kind must fit in 32 bits"
        case .kindZero:
            "'\(macroName)' kind 0 is reserved for empty slots"
        case .unsupportedDeclaration:
            "'\(macroName)' applies to a static property, a static function, a global variable, a free function, or a struct, enum, class or actor"
        case .instanceMember:
            "'\(macroName)' applies to static members only: a record has no instance to read"
        case .unnamedVariable:
            "'\(macroName)' applies to a variable with a name, not a tuple pattern"
        case .genericFunction:
            "'\(macroName)' cannot apply to a generic function: a record holds one concrete value"
        case .genericType:
            "'\(macroName)' cannot apply to a generic type: a record holds one concrete type"
        case .memberOfGenericType:
            "'\(macroName)' cannot apply to a member of a generic type: a record holds one concrete value"
        case .protocolRequirement:
            "'\(macroName)' cannot apply to a protocol's requirement: a record holds a value, and a requirement has none of its own"
        case .localDeclaration:
            "'\(macroName)' applies at file scope or in a type, not inside a function, closure or accessor: a record is a global"
        case .isolatedProperty:
            "'\(macroName)' cannot apply to a property isolated to the main actor: a record's accessor is nonisolated and can't read it; mark the property nonisolated, or register a @MainActor function that returns it"
        case .missingValue:
            "'\(macroName)' needs a 'storing:' expression: the value its record holds"
        case .emptyUniqueKey:
            "'\(macroName)' needs a unique key that isn't empty"
        case .uniqueKeyNotLiteral:
            "'\(macroName)' needs its unique key as a string literal without interpolation, such as 'uniqueKey: \"/home\"'"
        case .uniqueKeyInPrivateScope:
            "'\(macroName)' can't check its unique key inside a private or fileprivate type: the symbol that checks it would be local to the file; make the enclosing type internal or wider"
        }
    }

    public var diagnosticID: MessageID {
        MessageID(domain: "LinkerSetsMacroSupport", id: reason.rawValue)
    }

    /// Always an error: the macro writes no record for a declaration it refuses.
    public var severity: DiagnosticSeverity { .error }

    /// The error the expansion throws: this refusal as a diagnostic at ``node``.
    public var error: DiagnosticsError {
        DiagnosticsError(diagnostics: [Diagnostic(node: node, message: self)])
    }
}
