// A client's macro, the example's `@Route`, expanded: the library's record shape with the
// client's kind, and the library's diagnostics under the client's name. Each test is
// self-contained.

import ExampleRoutesMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("A client's macro: expansions")
struct ClientMacroTests {
    @Test("@Route writes the library's record with the client's kind and no argument")
    func routeExpansion() {
        let source = """
            enum Endpoints {
                @Route
                static let home = Endpoint(path: "/")
            }
            """
        let expected = """
            enum Endpoints {
                static let home = Endpoint(path: "/")

                #linkerSetRecord(kind: 0x726F7574, storing: Endpoints.home)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Route": MacroSpec(type: RouteMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("@Route's diagnostics name @Route")
    func routeDiagnostic() {
        let source = """
            struct S {
                @Route
                let home = 1
            }
            """
        let expected = """
            struct S {
                let home = 1
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'@Route' applies to static members only: a record has no instance to read", line: 2, column: 5)],
            macroSpecs: ["Route": MacroSpec(type: RouteMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
}
