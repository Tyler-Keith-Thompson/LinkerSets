import SwiftDiagnostics
import SwiftSyntax

/// What a linker-set macro refuses, each with the message the compiler shows, naming the macro
/// as it was written (`@Route`).
struct LinkerSetMacroDiagnostic: DiagnosticMessage, Error {
    /// The ways a declaration or a kind can be refused.
    enum Reason: String {
        case kindNotLiteral
        case kindOutOfRange
        case kindZero
        case unsupportedDeclaration
        case instanceMember
        case unnamedVariable
        case genericFunction
    }

    let reason: Reason
    /// The attribute as written, such as `@Route`.
    let macroName: String

    var message: String {
        switch reason {
        case .kindNotLiteral:
            "'\(macroName)' needs its kind as an integer literal, such as 'kind: 0x726F_7574'"
        case .kindOutOfRange:
            "'\(macroName)' kind must fit in 32 bits"
        case .kindZero:
            "'\(macroName)' kind 0 is reserved for empty slots"
        case .unsupportedDeclaration:
            "'\(macroName)' applies to a static property, a static function, a global variable or a free function"
        case .instanceMember:
            "'\(macroName)' applies to static members only: a record has no instance to read"
        case .unnamedVariable:
            "'\(macroName)' applies to a variable with a name, not a tuple pattern"
        case .genericFunction:
            "'\(macroName)' cannot apply to a generic function: a record holds one concrete value"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "LinkerSetsMacroSupport", id: reason.rawValue)
    }

    var severity: DiagnosticSeverity { .error }

    /// The error that reports `reason` at `node`.
    static func error(_ reason: Reason, at node: some SyntaxProtocol, macroName: String) -> DiagnosticsError {
        DiagnosticsError(diagnostics: [Diagnostic(node: Syntax(node), message: LinkerSetMacroDiagnostic(reason: reason, macroName: macroName))])
    }
}
