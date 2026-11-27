// A client's macro, the example's `@Route`, expanded: the library's record shape with the
// client's kind, and the library's diagnostics under the client's name. Each test is
// self-contained.

import ExampleRoutesMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("A client's macro: expansions")
struct ClientMacroTests {
    // See LinkerSetEntryMacroTests: 600 and 601's assertMacroExpansion leaves the `#if` among the
    // peer's attributes out of the expansion it reports.
    #if canImport(SwiftSyntax602)
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

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x726F7574, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(ELF) && _pointerBitWidth(_64)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x726F7574, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(ELF) && _pointerBitWidth(_32)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x726F7574, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(Wasm)
                @section("linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x726F7574, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(COFF)
                @section(".lnkset$M") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x726F7574, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                    }, 0, 0)
                #endif
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Route": MacroSpec(type: RouteMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
    #endif

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
