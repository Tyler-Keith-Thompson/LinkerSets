// How the linker-set macros treat declarations isolated to the main actor: a function keeps its
// isolation in the type it is stored as, and a property the record's nonisolated accessor can't
// read is refused. Each test is self-contained: it states its own input, expansion and macro table.

import LinkerSetsMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("@LinkerSetEntry: main-actor isolation")
struct IsolationExpansionTests {
    // swift-syntax 600 and 601's assertMacroExpansion leaves an `#if` among a peer's attributes
    // out of the expansion it reports, and a macro sees its enclosing type only from 600 on, so
    // these pin the source from 602 on.
    #if canImport(SwiftSyntax602)

    @Test("A static function of a @MainActor type is stored as its @MainActor function type")
    func mainActorType() {
        let source = """
            @MainActor
            enum Screens {
                @LinkerSetEntry(kind: 1)
                static func show() {}
            }
            """
        let expected = """
            @MainActor
            enum Screens {
                static func show() {}

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.show as @MainActor () -> Void, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(ELF) && _pointerBitWidth(_64)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.show as @MainActor () -> Void, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(ELF) && _pointerBitWidth(_32)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.show as @MainActor () -> Void, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(Wasm)
                @section("linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.show as @MainActor () -> Void, into: outValue, ifAsked: type)
                    }, 0, 0)
                #endif
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A @MainActor static function is stored as its @MainActor function type")
    func mainActorFunction() {
        let source = """
            enum Menu {
                @MainActor @LinkerSetEntry(kind: 1)
                static func open() {}
            }
            """
        let expected = """
            enum Menu {
                @MainActor
                static func open() {}

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.open as @MainActor () -> Void, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(ELF) && _pointerBitWidth(_64)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.open as @MainActor () -> Void, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(ELF) && _pointerBitWidth(_32)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.open as @MainActor () -> Void, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(Wasm)
                @section("linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.open as @MainActor () -> Void, into: outValue, ifAsked: type)
                    }, 0, 0)
                #endif
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A @MainActor extension's static function is stored as its @MainActor function type")
    func mainActorExtension() {
        let source = """
            @MainActor
            extension Menu {
                @LinkerSetEntry(kind: 1)
                static func close() {}
            }
            """
        let expected = """
            @MainActor
            extension Menu {
                static func close() {}

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.close as @MainActor () -> Void, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(ELF) && _pointerBitWidth(_64)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.close as @MainActor () -> Void, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(ELF) && _pointerBitWidth(_32)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.close as @MainActor () -> Void, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(Wasm)
                @section("linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.close as @MainActor () -> Void, into: outValue, ifAsked: type)
                    }, 0, 0)
                #endif
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A nonisolated static function of a @MainActor type is stored as its plain function type")
    func nonisolatedFunction() {
        let source = """
            @MainActor
            enum Screens {
                @LinkerSetEntry(kind: 1)
                nonisolated static func describe() -> String { "" }
            }
            """
        let expected = """
            @MainActor
            enum Screens {
                nonisolated static func describe() -> String { "" }

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.describe as () -> String, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(ELF) && _pointerBitWidth(_64)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.describe as () -> String, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(ELF) && _pointerBitWidth(_32)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.describe as () -> String, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(Wasm)
                @section("linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.describe as () -> String, into: outValue, ifAsked: type)
                    }, 0, 0)
                #endif
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A static let of a @MainActor type is stored as its value")
    func mainActorTypeLet() {
        let source = """
            @MainActor
            enum Titles {
                @LinkerSetEntry(kind: 1)
                static let home = "Home"
            }
            """
        let expected = """
            @MainActor
            enum Titles {
                static let home = "Home"

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(ELF) && _pointerBitWidth(_64)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(ELF) && _pointerBitWidth(_32)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x00000001, 0, { outValue, type, _, _ in
                            LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(Wasm)
                @section("linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                    }, 0, 0)
                #endif
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
    #endif

    @Test("A property isolated to the main actor gets its diagnostic at the declaration, and no record", arguments: [
        ("enum Labels {\n    @MainActor @LinkerSetEntry(kind: 1)\n    static let back = \"Back\"\n}", 2, 5, "enum Labels {\n    @MainActor\n    static let back = \"Back\"\n}"),
        ("@MainActor\nenum Counters {\n    @LinkerSetEntry(kind: 1)\n    static var taps = 0\n}", 3, 5, "@MainActor\nenum Counters {\n    static var taps = 0\n}"),
    ] as [(String, Int, Int, String)])
    func isolatedProperty(source: String, line: Int, column: Int, expectedSource: String) {
        let expectedMessage = "'@LinkerSetEntry' cannot apply to a property isolated to the main actor: a record's accessor is nonisolated and can't read it; mark the property nonisolated, or register a @MainActor function that returns it"

        assertMacroExpansion(
            source,
            expandedSource: expectedSource,
            diagnostics: [DiagnosticSpec(message: expectedMessage, line: line, column: column)],
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
}
