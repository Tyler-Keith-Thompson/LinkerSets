// The expansions `@LinkerSetEntry` writes, pinned as source. Each test is self-contained: it
// states its own input, expansion and macro table.

import LinkerSetsMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("@LinkerSetEntry: expansions")
struct LinkerSetEntryMacroTests {
    // swift-syntax 600 and 601's assertMacroExpansion leaves an `#if` among a peer's attributes
    // out of the expansion it reports, though the plugin writes it and the compiler compiles it
    // (LinkerSetsTests finds the records on those versions), so these pin the source from 602 on.
    #if canImport(SwiftSyntax602)
    @Test("A static property becomes a private static record that stores Self.property")
    func staticProperty() {
        let source = """
            enum Routes {
                @LinkerSetEntry(kind: 0x726F_7574)
                static let home = Route(path: "/")
            }
            """
        let expected = """
            enum Routes {
                static let home = Route(path: "/")

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets")
                #elseif objectFormat(ELF)
                @section("linker_sets")
                #endif
                @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x726F7574, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
                    }, 0, 0)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A static function becomes a record that stores it by its full name as its function type")
    func staticFunction() {
        let source = """
            extension Handlers {
                @LinkerSetEntry(kind: 42)
                static func handle(_ request: Request, retries: Int...) async throws(HandlerError) -> Response {
                    Response()
                }
            }
            """
        let expected = """
            extension Handlers {
                static func handle(_ request: Request, retries: Int...) async throws(HandlerError) -> Response {
                    Response()
                }

                #if objectFormat(MachO)
                @section("__DATA_CONST,__linker_sets")
                #elseif objectFormat(ELF)
                @section("linker_sets")
                #endif
                @used private static let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x0000002A, 0, { outValue, type, _, _ in
                        LinkerSets.LinkerSetRecord.__store(Self.handle(_:retries:) as (Request, Int...) async throws(HandlerError) -> Response, into: outValue, ifAsked: type)
                    }, 0, 0)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A free function with no parameters becomes a global record of type () -> Void")
    func freeFunction() {
        let source = """
            @LinkerSetEntry(kind: 0b1)
            func migrate() {}
            """
        let expected = """
            func migrate() {}

            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets")
            #elseif objectFormat(ELF)
            @section("linker_sets")
            #endif
            @used private let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                    LinkerSets.LinkerSetRecord.__store(migrate as () -> Void, into: outValue, ifAsked: type)
                }, 0, 0)
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A global variable becomes a global record that stores it")
    func globalVariable() {
        let source = """
            @LinkerSetEntry(kind: 0o7)
            let banner: String = "hi"
            """
        let expected = """
            let banner: String = "hi"

            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets")
            #elseif objectFormat(ELF)
            @section("linker_sets")
            #endif
            @used private let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000007, 0, { outValue, type, _, _ in
                    LinkerSets.LinkerSetRecord.__store(banner, into: outValue, ifAsked: type)
                }, 0, 0)
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("The kind's boundaries: 1 and UInt32.max are accepted")
    func kindBoundaries() {
        let source = """
            @LinkerSetEntry(kind: 1)
            let first = 1
            @LinkerSetEntry(kind: 0xFFFF_FFFF)
            let last = 2
            """
        let expected = """
            let first = 1

            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets")
            #elseif objectFormat(ELF)
            @section("linker_sets")
            #endif
            @used private let __macro_local_15linkerSetRecordfMu_: LinkerSets.LinkerSetRecord.Literal = (0x00000001, 0, { outValue, type, _, _ in
                    LinkerSets.LinkerSetRecord.__store(first, into: outValue, ifAsked: type)
                }, 0, 0)
            let last = 2

            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets")
            #elseif objectFormat(ELF)
            @section("linker_sets")
            #endif
            @used private let __macro_local_15linkerSetRecordfMu0_: LinkerSets.LinkerSetRecord.Literal = (0xFFFFFFFF, 0, { outValue, type, _, _ in
                    LinkerSets.LinkerSetRecord.__store(last, into: outValue, ifAsked: type)
                }, 0, 0)
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
    #endif

    @Test("Each refused declaration gets its diagnostic, where it applies, and no record", arguments: [
        ("@LinkerSetEntry(kind: routes)\nlet a = 1", "'@LinkerSetEntry' needs its kind as an integer literal, such as 'kind: 0x726F_7574'", 1, 1, "let a = 1"),
        ("@LinkerSetEntry(kind: 0x1_0000_0000)\nlet a = 1", "'@LinkerSetEntry' kind must fit in 32 bits", 1, 23, "let a = 1"),
        ("@LinkerSetEntry(kind: 0)\nlet a = 1", "'@LinkerSetEntry' kind 0 is reserved for empty slots", 1, 23, "let a = 1"),
        ("@LinkerSetEntry(kind: 1)\nprotocol P {}", "'@LinkerSetEntry' applies to a static property, a static function, a global variable, a free function, or a struct, enum, class or actor", 1, 1, "protocol P {}"),
        ("@LinkerSetEntry(kind: 1)\nextension S {}", "'@LinkerSetEntry' applies to a static property, a static function, a global variable, a free function, or a struct, enum, class or actor", 1, 1, "extension S {}"),
        ("@LinkerSetEntry(kind: 1)\nstruct Box<T> {}", "'@LinkerSetEntry' cannot apply to a generic type: a record holds one concrete type", 1, 1, "struct Box<T> {}"),
        ("struct S {\n    @LinkerSetEntry(kind: 1)\n    let a = 1\n}", "'@LinkerSetEntry' applies to static members only: a record has no instance to read", 2, 5, "struct S {\n    let a = 1\n}"),
        ("struct S {\n    @LinkerSetEntry(kind: 1)\n    func f() {}\n}", "'@LinkerSetEntry' applies to static members only: a record has no instance to read", 2, 5, "struct S {\n    func f() {}\n}"),
        ("@LinkerSetEntry(kind: 1)\nlet (a, b) = (1, 2)", "'@LinkerSetEntry' applies to a variable with a name, not a tuple pattern", 1, 1, "let (a, b) = (1, 2)"),
        ("@LinkerSetEntry(kind: 1)\nfunc f<T>(_ value: T) {}", "'@LinkerSetEntry' cannot apply to a generic function: a record holds one concrete value", 1, 1, "func f<T>(_ value: T) {}"),
    ] as [(String, String, Int, Int, String)])
    func refused(source: String, expectedMessage: String, line: Int, column: Int, expectedSource: String) {
        assertMacroExpansion(
            source,
            expandedSource: expectedSource,
            diagnostics: [DiagnosticSpec(message: expectedMessage, line: line, column: column)],
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
}
