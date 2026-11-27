// The records a type becomes: its metatype, as `any P.Type` for a macro that requires a protocol
// (the example's `@Event`, which requires AnalyticsEvent and keys each event by its type's name)
// and as `Any.Type` for `@LinkerSetEntry`.
// Each test is self-contained.

import ExampleEventsMacros
import LinkerSetsMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Types: expansions")
struct TypeExpansionTests {
    @Test("A struct at file scope becomes a global record of its metatype as the required protocol's")
    func structAtFileScope() {
        let source = """
            @Event
            struct Login: AnalyticsEvent {}
            """
        let expected = """
            struct Login: AnalyticsEvent {}

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x65766E74, storing: Login.self as any (ExampleEvents.AnalyticsEvent).Type)
            }

            @_silgen_name("$linkerset_kind_65766E74_key_Login") @used nonisolated func __macro_local_18linkerSetUniqueKeyfMu_() {
            }
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

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x65766E74, storing: Logout.self as any (ExampleEvents.AnalyticsEvent).Type)
            }

            @_silgen_name("$linkerset_kind_65766E74_key_Logout") @used nonisolated func __macro_local_18linkerSetUniqueKeyfMu_() {
            }
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

                #linkerSetRecord(kind: 0x65766E74, storing: Self.Purchase.self as any (ExampleEvents.AnalyticsEvent).Type)

                @_silgen_name("$linkerset_kind_65766E74_key_Purchase") @used nonisolated static func __macro_local_18linkerSetUniqueKeyfMu_() {
                }
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

                #linkerSetRecord(kind: 0x65766E74, storing: Self.Refund.self as any (ExampleEvents.AnalyticsEvent).Type)

                @_silgen_name("$linkerset_kind_65766E74_key_Refund") @used nonisolated static func __macro_local_18linkerSetUniqueKeyfMu_() {
                }
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

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x706C7567, storing: Plugin.self as Any.Type)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

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
            diagnostics: [DiagnosticSpec(message: "'@Event' cannot apply to a generic type: a record holds one concrete type", line: 2, column: 14)],
            macroSpecs: ["Event": MacroSpec(type: EventMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
}
