// The record `#linkerSetRecord` writes, one declaration per object format, which every
// linker-set macro's expansion calls. Each test is self-contained.

import LinkerSetsMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("#linkerSetRecord: the record each object format holds")
struct LinkerSetRecordMacroTests {
    // swift-syntax 600 and 601's assertMacroExpansion leaves an `#if` in an expansion out of the
    // source it reports, though the plugin writes it and the compiler compiles it (LinkerSetsTests
    // finds the records on those versions), so this pins the source from 602 on.
    #if canImport(SwiftSyntax602)
    @Test("A record is a private static member under one #if branch per object format")
    func recordPerObjectFormat() {
        let source = """
            enum Routes {
                #linkerSetRecord(kind: 0x726F7574, storing: Self.home)
            }
            """
        let expected = """
            enum Routes {
                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x726F7574, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(ELF) && _pointerBitWidth(_64)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x726F7574, 0, { outValue, type, _, _ in
                            LinkerSetsRuntime.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(ELF) && _pointerBitWidth(_32)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x726F7574, 0, { outValue, type, _, _ in
                            LinkerSetsRuntime.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(Wasm)
                @section("linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x726F7574, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(COFF)
                @section(".lnkset$M") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x726F7574, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                    }, 0, 0)
                #endif
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["linkerSetRecord": MacroSpec(type: LinkerSetRecordMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
    #endif

    @Test("A call without its storing: expression gets a diagnostic and is left unexpanded")
    func missingValue() {
        let source = """
            enum Routes {
                #linkerSetRecord(kind: 0x726F7574)
            }
            """
        let expected = """
            enum Routes {
                #linkerSetRecord(kind: 0x726F7574)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'#linkerSetRecord' needs a 'storing:' expression: the value its record holds", line: 2, column: 5)],
            macroSpecs: ["linkerSetRecord": MacroSpec(type: LinkerSetRecordMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("Each refused kind gets its diagnostic and is left unexpanded", arguments: [
        ("#linkerSetRecord(kind: routes, storing: Self.home)", "'#linkerSetRecord' needs its kind as an integer literal, such as 'kind: 0x726F_7574'", 5),
        ("#linkerSetRecord(kind: 0x1_0000_0000, storing: Self.home)", "'#linkerSetRecord' kind must fit in 32 bits", 28),
        ("#linkerSetRecord(kind: 0, storing: Self.home)", "'#linkerSetRecord' kind 0 is reserved for empty slots", 28),
    ])
    func refusedKind(call: String, expectedMessage: String, expectedColumn: Int) {
        let source = """
            enum Routes {
                \(call)
            }
            """
        let expected = """
            enum Routes {
                \(call)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: expectedMessage, line: 2, column: expectedColumn)],
            macroSpecs: ["linkerSetRecord": MacroSpec(type: LinkerSetRecordMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
}
