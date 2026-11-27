import SwiftDiagnostics

/// What `@LinkerSetEntry` refuses, each with the message the compiler shows.
enum LinkerSetEntryDiagnostic: String, DiagnosticMessage, Error {
    case kindNotLiteral
    case kindOutOfRange
    case kindZero
    case unsupportedDeclaration
    case instanceMember
    case unnamedVariable
    case genericFunction

    var message: String {
        switch self {
        case .kindNotLiteral:
            "'@LinkerSetEntry' needs its kind as an integer literal, such as 'kind: 0x726F_7574'"
        case .kindOutOfRange:
            "'@LinkerSetEntry' kind must fit in 32 bits"
        case .kindZero:
            "'@LinkerSetEntry' kind 0 is reserved for empty slots"
        case .unsupportedDeclaration:
            "'@LinkerSetEntry' applies to a static property, a static function, a global variable or a free function"
        case .instanceMember:
            "'@LinkerSetEntry' applies to static members only: a record has no instance to read"
        case .unnamedVariable:
            "'@LinkerSetEntry' applies to a variable with a name, not a tuple pattern"
        case .genericFunction:
            "'@LinkerSetEntry' cannot apply to a generic function: a record holds one concrete value"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "LinkerSetsMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
