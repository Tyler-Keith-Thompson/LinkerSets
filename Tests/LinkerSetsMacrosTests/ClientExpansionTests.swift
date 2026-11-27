// The API a client macro uses when it writes its own expansion: the library's record peers
// (`recordPeers`), and the check that says why a declaration can't hold a record (`refusal`).
// Each test is self-contained; the client macros are declared here, as a client's plugin would.

import LinkerSetsMacroSupport
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// A client's `@Event` with two roles: an extension that adds the conformance, and the record,
/// skipped with a note for a generic type.
enum ConformingEventMacro: LinkerSetMacro, ExtensionMacro {
    static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6576_6E74 }  // "evnt"

    static func requiredConformance(of attribute: AttributeSyntax) -> TypeSyntax? {
        "Events.AnalyticsEvent"
    }

    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let refusal = try refusal(of: node, providingPeersOf: declaration, in: context), refusal.reason == .genericType {
            context.diagnose(Diagnostic(node: refusal.node, message: NotDiscovered()))
            return []
        }
        return try recordPeers(of: node, providingPeersOf: declaration, in: context)
    }

    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        [try ExtensionDeclSyntax("extension \(type.trimmed): Events.AnalyticsEvent {}")]
    }
}

/// The note `ConformingEventMacro` gives a generic type.
struct NotDiscovered: DiagnosticMessage {
    var message: String { "a generic event isn't discovered; list it by hand" }
    var diagnosticID: MessageID { MessageID(domain: "Events", id: "notDiscovered") }
    var severity: DiagnosticSeverity { .note }
}

/// A macro that writes nothing and reports `refusal`'s answer as a note: the reason, or
/// "recordable".
enum RefusalProbeMacro: LinkerSetMacro {
    static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x7072_6F62 }  // "prob"

    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let refusal = try refusal(of: node, providingPeersOf: declaration, in: context)
        context.diagnose(Diagnostic(node: refusal?.node ?? Syntax(node), message: ProbeNote(answer: refusal.map { "\($0.reason)" } ?? "recordable")))
        return []
    }
}

/// `RefusalProbeMacro`'s note.
struct ProbeNote: DiagnosticMessage {
    let answer: String
    var message: String { answer }
    var diagnosticID: MessageID { MessageID(domain: "Probe", id: answer) }
    var severity: DiagnosticSeverity { .note }
}

@Suite("A client macro's own expansion: recordPeers and refusal")
struct ClientExpansionTests {
    @Test("A macro that writes its own expansion gets the library's record from recordPeers, beside its extension")
    func recordPeersBesideExtension() {
        let source = """
            @Event
            struct Login {
            }
            """
        let expected = """
            struct Login {
            }

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x65766E74, storing: Login.self as any (Events.AnalyticsEvent).Type)
            }

            extension Login: Events.AnalyticsEvent {
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Event": MacroSpec(type: ConformingEventMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("recordPeers writes the same record as the default expansion")
    func recordPeersMatchesDefault() {
        let source = """
            enum Screens {
                @Event
                static let home = 1
            }
            """
        let expected = """
            enum Screens {
                static let home = 1

                #linkerSetRecord(kind: 0x65766E74, storing: Screens.home)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Event": MacroSpec(type: ConformingEventMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A macro that skips generic types gives its own note and writes no record")
    func genericTypeNote() {
        let source = """
            @Event
            struct Box<T> {
            }
            """
        let expected = """
            struct Box<T> {
            }

            extension Box: Events.AnalyticsEvent {
            }
            """
        let expectedMessage = "a generic event isn't discovered; list it by hand"

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: expectedMessage, line: 2, column: 11, severity: .note)],
            macroSpecs: ["Event": MacroSpec(type: ConformingEventMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("refusal names a generic declaration's reason, and nil for one that can hold a record", arguments: [
        ("@Probe\nstruct Box<T> {\n}", "struct Box<T> {\n}", "genericType", 2, 11),
        ("@Probe\nfunc make<T>() -> T? { nil }", "func make<T>() -> T? { nil }", "genericFunction", 2, 10),
        ("enum Settings {\n    @Probe\n    static let volume = 1\n}", "enum Settings {\n    static let volume = 1\n}", "recordable", 2, 5),
        ("enum Settings {\n    @Probe\n    let volume = 1\n}", "enum Settings {\n    let volume = 1\n}", "instanceMember", 2, 5),
    ] as [(String, String, String, Int, Int)])
    func declarationRefusal(source: String, expectedSource: String, expectedAnswer: String, line: Int, column: Int) {
        assertMacroExpansion(
            source,
            expandedSource: expectedSource,
            diagnostics: [DiagnosticSpec(message: expectedAnswer, line: line, column: column, severity: .note)],
            macroSpecs: ["Probe": MacroSpec(type: RefusalProbeMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    // A macro sees where its declaration sits from swift-syntax 600 on.
    #if canImport(SwiftSyntax600)
    @Test("refusal names the reason a declaration's scope can't hold a record", arguments: [
        ("func setUp() {\n    @Probe\n    let volume = 1\n}", "func setUp() {\n    let volume = 1\n}", "localDeclaration"),
        ("protocol Configurable {\n    @Probe\n    static var volume: Int { get }\n}", "protocol Configurable {\n    static var volume: Int { get }\n}", "protocolRequirement"),
        ("struct Box<T> {\n    @Probe\n    static let volume = 1\n}", "struct Box<T> {\n    static let volume = 1\n}", "memberOfGenericType"),
    ] as [(String, String, String)])
    func scopeRefusal(source: String, expectedSource: String, expectedAnswer: String) {
        assertMacroExpansion(
            source,
            expandedSource: expectedSource,
            diagnostics: [DiagnosticSpec(message: expectedAnswer, line: 2, column: 5, severity: .note)],
            macroSpecs: ["Probe": MacroSpec(type: RefusalProbeMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
    #endif
}
