// The records a type becomes: its metatype, as `any P.Type` for a macro that requires a protocol
// (the example's `@Event`, which requires AnalyticsEvent) and as `Any.Type` for `@LinkerSetEntry`.
// Each test is self-contained.

import ExampleEventsMacros
import LinkerSetsMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Types: expansions")
struct TypeExpansionTests {
    // See LinkerSetEntryMacroTests: 600 and 601's assertMacroExpansion leaves the `#if` among the
    // peer's attributes out of the expansion it reports.
    #if canImport(SwiftSyntax602)
    @Test("A struct at file scope becomes a global record of its metatype as the required protocol's")
    func structAtFileScope() {
        let source = """
            @Event
            struct Login: AnalyticsEvent {}
            """
        let expected = """
            struct Login: AnalyticsEvent {}

            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                    LinkerSetsRuntime.LinkerSetRecord.__store(Login.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                }, 0, 0)
            #elseif objectFormat(ELF) && _pointerBitWidth(_64)
            @section(".note.linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Login.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0))
            #elseif objectFormat(ELF) && _pointerBitWidth(_32)
            @section(".note.linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Login.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0))
            #elseif objectFormat(Wasm)
            @section("linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                    LinkerSetsRuntime.LinkerSetRecord.__store(Login.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                }, 0, 0)
            #elseif objectFormat(COFF)
            @section(".lnkset$M") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                    LinkerSetsRuntime.LinkerSetRecord.__store(Login.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                }, 0, 0)
            #endif
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Event": MacroSpec(type: EventMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("An enum at file scope becomes a global record of its metatype")
    func enumAtFileScope() {
        let source = """
            @Event
            enum Logout: AnalyticsEvent {}
            """
        let expected = """
            enum Logout: AnalyticsEvent {}

            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                    LinkerSetsRuntime.LinkerSetRecord.__store(Logout.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                }, 0, 0)
            #elseif objectFormat(ELF) && _pointerBitWidth(_64)
            @section(".note.linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Logout.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0))
            #elseif objectFormat(ELF) && _pointerBitWidth(_32)
            @section(".note.linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Logout.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0))
            #elseif objectFormat(Wasm)
            @section("linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                    LinkerSetsRuntime.LinkerSetRecord.__store(Logout.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                }, 0, 0)
            #elseif objectFormat(COFF)
            @section(".lnkset$M") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                    LinkerSetsRuntime.LinkerSetRecord.__store(Logout.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                }, 0, 0)
            #endif
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Event": MacroSpec(type: EventMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A class nested in a type becomes a static record that names it through Self")
    func nestedClass() {
        let source = """
            enum Checkout {
                @Event
                final class Purchase: AnalyticsEvent {}
            }
            """
        let expected = """
            enum Checkout {
                final class Purchase: AnalyticsEvent {}

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Self.Purchase.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(ELF) && _pointerBitWidth(_64)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x65766E74, 0, { outValue, type, _, _ in
                            LinkerSetsRuntime.LinkerSetRecord.__store(Self.Purchase.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(ELF) && _pointerBitWidth(_32)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x65766E74, 0, { outValue, type, _, _ in
                            LinkerSetsRuntime.LinkerSetRecord.__store(Self.Purchase.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(Wasm)
                @section("linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Self.Purchase.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(COFF)
                @section(".lnkset$M") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Self.Purchase.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0)
                #endif
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Event": MacroSpec(type: EventMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("An actor in an extension becomes a static record that names it through Self")
    func actorInExtension() {
        let source = """
            extension Checkout {
                @Event
                actor Refund: AnalyticsEvent {}
            }
            """
        let expected = """
            extension Checkout {
                actor Refund: AnalyticsEvent {}

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Self.Refund.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(ELF) && _pointerBitWidth(_64)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x65766E74, 0, { outValue, type, _, _ in
                            LinkerSetsRuntime.LinkerSetRecord.__store(Self.Refund.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(ELF) && _pointerBitWidth(_32)
                @section(".note.linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x65766E74, 0, { outValue, type, _, _ in
                            LinkerSetsRuntime.LinkerSetRecord.__store(Self.Refund.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                        }, 0, 0))
                #elseif objectFormat(Wasm)
                @section("linker_sets") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Self.Refund.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0)
                #elseif objectFormat(COFF)
                @section(".lnkset$M") @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x65766E74, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Self.Refund.self as any (ExampleEvents.AnalyticsEvent).Type, into: outValue, ifAsked: type)
                    }, 0, 0)
                #endif
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Event": MacroSpec(type: EventMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("@LinkerSetEntry, which requires no protocol, stores a type as Any.Type")
    func entryStoresAnyType() {
        let source = """
            @LinkerSetEntry(kind: 0x706C_7567)
            struct Plugin {}
            """
        let expected = """
            struct Plugin {}

            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x706C7567, 0, { outValue, type, _, _ in
                    LinkerSetsRuntime.LinkerSetRecord.__store(Plugin.self as Any.Type, into: outValue, ifAsked: type)
                }, 0, 0)
            #elseif objectFormat(ELF) && _pointerBitWidth(_64)
            @section(".note.linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x706C7567, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Plugin.self as Any.Type, into: outValue, ifAsked: type)
                    }, 0, 0))
            #elseif objectFormat(ELF) && _pointerBitWidth(_32)
            @section(".note.linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x706C7567, 0, { outValue, type, _, _ in
                        LinkerSetsRuntime.LinkerSetRecord.__store(Plugin.self as Any.Type, into: outValue, ifAsked: type)
                    }, 0, 0))
            #elseif objectFormat(Wasm)
            @section("linker_sets") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x706C7567, 0, { outValue, type, _, _ in
                    LinkerSetsRuntime.LinkerSetRecord.__store(Plugin.self as Any.Type, into: outValue, ifAsked: type)
                }, 0, 0)
            #elseif objectFormat(COFF)
            @section(".lnkset$M") @used private let __macro_local_15linkerSetRecordfMu_: LinkerSetsRuntime.LinkerSetRecord.Literal = (0x706C7567, 0, { outValue, type, _, _ in
                    LinkerSetsRuntime.LinkerSetRecord.__store(Plugin.self as Any.Type, into: outValue, ifAsked: type)
                }, 0, 0)
            #endif
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
    #endif

    @Test("A generic type is refused under the client's name, with no record")
    func genericTypeRefused() {
        let source = """
            @Event
            struct Tagged<Payload>: AnalyticsEvent {}
            """
        let expected = """
            struct Tagged<Payload>: AnalyticsEvent {}
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'@Event' cannot apply to a generic type: a record holds one concrete type", line: 1, column: 1)],
            macroSpecs: ["Event": MacroSpec(type: EventMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
}
