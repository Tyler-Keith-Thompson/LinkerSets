// A client's macro that calls a record macro of its own (the example's `@Discoverable(kind:)` and
// `#discoverableRecord`), so its users needn't depend on LinkerSets. Each test is self-contained.

import ExampleDiscoveryMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("A client's own record macro: expansions")
struct OwnRecordMacroTests {
    @Test("A macro naming its own record macro calls it in place of #linkerSetRecord")
    func memberExpansion() {
        let source = """
            enum SessionEvents {
                @Discoverable(kind: 0x7365_7373)
                static let started = "session started"
            }
            """
        let expected = """
            enum SessionEvents {
                static let started = "session started"

                #discoverableRecord(kind: 0x73657373, storing: Self.started)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Discoverable": MacroSpec(type: DiscoverableMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A global's record calls the client's record macro inside its private enum")
    func globalExpansion() {
        let source = """
            @Discoverable(kind: 0x7365_7373)
            let sessionTimedOut = "session timed out"
            """
        let expected = """
            let sessionTimedOut = "session timed out"

            private enum __macro_local_15linkerSetRecordfMu_ {
                #discoverableRecord(kind: 0x73657373, storing: sessionTimedOut)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Discoverable": MacroSpec(type: DiscoverableMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("The client's record macro's diagnostics name it")
    func recordMacroDiagnostic() {
        let source = """
            enum SessionEvents {
                #discoverableRecord(kind: 0x7365_7373)
            }
            """
        let expected = """
            enum SessionEvents {
                #discoverableRecord(kind: 0x7365_7373)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'#discoverableRecord' needs a 'storing:' expression: the value its record holds", line: 2, column: 5)],
            macroSpecs: ["discoverableRecord": MacroSpec(type: DiscoverableRecordMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
}
