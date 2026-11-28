// The expansions `@LinkerSetEntry` writes, pinned as source. Each test is self-contained: it
// states its own input, expansion and macro table.

import LinkerSetsMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("@LinkerSetEntry: expansions")
struct LinkerSetEntryMacroTests {
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

                #linkerSetRecord(kind: 0x726F7574, storing: Routes.home)
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

                #linkerSetRecord(kind: 0x0000002A, storing: Handlers.handle(_:retries:) as (Request, Int...) async throws(HandlerError) -> Response)
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

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x00000001, storing: migrate as () -> Void)
            }
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

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x00000007, storing: banner)
            }
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

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x00000001, storing: first)
            }
            let last = 2

            private enum __macro_local_15linkerSetRecordfMu0_ {
                #linkerSetRecord(kind: 0xFFFFFFFF, storing: last)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("Each refused declaration gets its diagnostic, where it applies, and no record", arguments: [
        ("@LinkerSetEntry(kind: routes)\nlet a = 1", "'@LinkerSetEntry' needs its kind as an integer literal, such as 'kind: 0x726F_7574'", 1, 1, "let a = 1"),
        ("@LinkerSetEntry(kind: 0x1_0000_0000)\nlet a = 1", "'@LinkerSetEntry' kind must fit in 32 bits", 1, 23, "let a = 1"),
        ("@LinkerSetEntry(kind: 0)\nlet a = 1", "'@LinkerSetEntry' kind 0 is reserved for empty slots", 1, 23, "let a = 1"),
        ("@LinkerSetEntry(kind: 1)\nprotocol P {}", "'@LinkerSetEntry' applies to a static property, a static function, a global variable, a free function, or a struct, enum, class or actor", 1, 1, "protocol P {}"),
        ("@LinkerSetEntry(kind: 1)\nextension S {}", "'@LinkerSetEntry' applies to a static property, a static function, a global variable, a free function, or a struct, enum, class or actor", 1, 1, "extension S {}"),
        ("@LinkerSetEntry(kind: 1)\nstruct Box<T> {}", "'@LinkerSetEntry' cannot apply to a generic type: a record holds one concrete type", 2, 11, "struct Box<T> {}"),
        ("struct S {\n    @LinkerSetEntry(kind: 1)\n    let a = 1\n}", "'@LinkerSetEntry' applies to static members only: a record has no instance to read", 2, 5, "struct S {\n    let a = 1\n}"),
        ("struct S {\n    @LinkerSetEntry(kind: 1)\n    func f() {}\n}", "'@LinkerSetEntry' applies to static members only: a record has no instance to read", 2, 5, "struct S {\n    func f() {}\n}"),
        ("@LinkerSetEntry(kind: 1)\nlet (a, b) = (1, 2)", "'@LinkerSetEntry' applies to a variable with a name, not a tuple pattern", 1, 1, "let (a, b) = (1, 2)"),
        ("@LinkerSetEntry(kind: 1)\nfunc f<T>(_ value: T) {}", "'@LinkerSetEntry' cannot apply to a generic function: a record holds one concrete value", 2, 7, "func f<T>(_ value: T) {}"),
        ("struct Box<T> {\n    @LinkerSetEntry(kind: 1)\n    static let a = 1\n}", "'@LinkerSetEntry' cannot apply to a member of a generic type: a record holds one concrete value", 2, 5, "struct Box<T> {\n    static let a = 1\n}"),
        ("enum Outer<T> {\n    enum Inner {\n        @LinkerSetEntry(kind: 1)\n        static func f() {}\n    }\n}", "'@LinkerSetEntry' cannot apply to a member of a generic type: a record holds one concrete value", 3, 9, "enum Outer<T> {\n    enum Inner {\n        static func f() {}\n    }\n}"),
        ("class Box<T> {\n    @LinkerSetEntry(kind: 1)\n    struct Inner {}\n}", "'@LinkerSetEntry' cannot apply to a member of a generic type: a record holds one concrete value", 2, 5, "class Box<T> {\n    struct Inner {}\n}"),
        ("extension Box<Int> {\n    @LinkerSetEntry(kind: 1)\n    static let a = 1\n}", "'@LinkerSetEntry' cannot apply to a member of a generic type: a record holds one concrete value", 2, 5, "extension Box<Int> {\n    static let a = 1\n}"),
        ("extension Outer.Box<Int> {\n    @LinkerSetEntry(kind: 1)\n    static func f() {}\n}", "'@LinkerSetEntry' cannot apply to a member of a generic type: a record holds one concrete value", 2, 5, "extension Outer.Box<Int> {\n    static func f() {}\n}"),
        ("extension Box<Int>.Inner {\n    @LinkerSetEntry(kind: 1)\n    static let a = 1\n}", "'@LinkerSetEntry' cannot apply to a member of a generic type: a record holds one concrete value", 2, 5, "extension Box<Int>.Inner {\n    static let a = 1\n}"),
        ("extension [Int] {\n    @LinkerSetEntry(kind: 1)\n    static let a = 1\n}", "'@LinkerSetEntry' cannot apply to a member of a generic type: a record holds one concrete value", 2, 5, "extension [Int] {\n    static let a = 1\n}"),
        ("extension Box where T == Int {\n    @LinkerSetEntry(kind: 1)\n    struct Inner {}\n}", "'@LinkerSetEntry' cannot apply to a member of a generic type: a record holds one concrete value", 2, 5, "extension Box where T == Int {\n    struct Inner {}\n}"),
        ("protocol P {\n    @LinkerSetEntry(kind: 1)\n    static func f()\n}", "'@LinkerSetEntry' cannot apply to a protocol's requirement: a record holds a value, and a requirement has none of its own", 2, 5, "protocol P {\n    static func f()\n}"),
        ("func f() {\n    @LinkerSetEntry(kind: 1)\n    let a = 1\n}", "'@LinkerSetEntry' applies at file scope or in a type, not inside a function, closure or accessor: a record is a global", 2, 5, "func f() {\n    let a = 1\n}"),
        ("let c = {\n    @LinkerSetEntry(kind: 1)\n    func g() {}\n}", "'@LinkerSetEntry' applies at file scope or in a type, not inside a function, closure or accessor: a record is a global", 2, 5, "let c = {\n    func g() {}\n}"),
        ("func f() {\n    struct Local {\n        @LinkerSetEntry(kind: 1)\n        static let a = 1\n    }\n}", "'@LinkerSetEntry' applies at file scope or in a type, not inside a function, closure or accessor: a record is a global", 3, 9, "func f() {\n    struct Local {\n        static let a = 1\n    }\n}"),
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
