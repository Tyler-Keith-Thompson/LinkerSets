// A unique key: the function whose symbol, named for the kind and the key, makes the linker refuse
// a second record of the kind with that key. The client macro here takes its key from a string
// argument, as a route's path would be. Each test is self-contained.

import LinkerSetsMacroSupport
import LinkerSetsMacros
import LinkerSetsTestSupport
import PropertyBased
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// `@Keyed("…")`: a record of kind `"keyd"` whose key is the attribute's string literal, and no
/// key without one.
enum KeyedMacro: LinkerSetMacro {
    static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6B65_7964 }  // "keyd"

    static func uniqueKey(of declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) throws -> String? {
        guard let argument = attribute.arguments?.as(LabeledExprListSyntax.self)?.first else { return nil }
        guard let literal = argument.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue else {
            throw DiagnosticsError(diagnostics: [Diagnostic(node: argument, message: KeyNotLiteral())])
        }
        return literal
    }
}

/// `KeyedMacro`'s own error, for a key that isn't a string literal.
struct KeyNotLiteral: DiagnosticMessage {
    var message: String { "'@Keyed' needs its key as a string literal" }
    var diagnosticID: MessageID { MessageID(domain: "Keyed", id: "keyNotLiteral") }
    var severity: DiagnosticSeverity { .error }
}

@Suite("A unique key: expansions")
struct UniqueKeyExpansionTests {
    @Test("A key on a type at file scope adds an internal function named for the kind and the key")
    func keyAtFileScope() {
        let source = """
            @Keyed("login")
            struct Login {}
            """
        let expected = """
            struct Login {}

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x6B657964, storing: Login.self as Any.Type)
            }

            @_silgen_name("$linkerset_kind_6B657964_key_login") @used nonisolated func __macro_local_18linkerSetUniqueKeyfMu_() {
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A key on a static member adds a static function beside the record")
    func keyOnStaticMember() {
        let source = """
            enum Routes {
                @Keyed("home")
                static func home() {}
            }
            """
        let expected = """
            enum Routes {
                static func home() {}

                #linkerSetRecord(kind: 0x6B657964, storing: Self.home as () -> Void)

                @_silgen_name("$linkerset_kind_6B657964_key_home") @used nonisolated static func __macro_local_18linkerSetUniqueKeyfMu_() {
                }
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A private declaration at file scope still gets an internal function, whose symbol the linker compares")
    func privateDeclarationAtFileScope() {
        let source = """
            @Keyed("audit")
            private let audit = 1
            """
        let expected = """
            private let audit = 1

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x6B657964, storing: audit)
            }

            @_silgen_name("$linkerset_kind_6B657964_key_audit") @used nonisolated func __macro_local_18linkerSetUniqueKeyfMu_() {
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("Letters and digits stay as they are; every other UTF-8 byte, underscore included, is _ and two hex digits, a tab _09")
    func keyEncoding() {
        let source = """
            @Keyed("v2/order_placed é\\t")
            struct OrderPlaced {}
            """
        let expected = """
            struct OrderPlaced {}

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x6B657964, storing: OrderPlaced.self as Any.Type)
            }

            @_silgen_name("$linkerset_kind_6B657964_key_v2_2Forder_5Fplaced_20_C3_A9_09") @used nonisolated func __macro_local_18linkerSetUniqueKeyfMu_() {
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("Without a key there is no function, only the record")
    func noKey() {
        let source = """
            @Keyed
            struct Plain {}
            """
        let expected = """
            struct Plain {}

            private enum __macro_local_15linkerSetRecordfMu_ {
                #linkerSetRecord(kind: 0x6B657964, storing: Plain.self as Any.Type)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("An empty key is refused at the attribute, with no record")
    func emptyKeyRefused() {
        let source = """
            @Keyed("")
            struct Nameless {}
            """
        let expected = """
            struct Nameless {}
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'@Keyed' needs a unique key that isn't empty", line: 1, column: 1)],
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A key that the client's hook refuses is the client's own error")
    func clientRefusesKey() {
        let source = """
            @Keyed(path)
            struct Dynamic {}
            """
        let expected = """
            struct Dynamic {}
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'@Keyed' needs its key as a string literal", line: 1, column: 8)],
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("@LinkerSetEntry's uniqueKey: argument is the key, its escapes resolved")
    func entryUniqueKeyArgument() {
        let source = #"""
            enum Routes {
                @LinkerSetEntry(kind: 0x726F_7574, uniqueKey: "\u{2F}home")
                static let home = 1
            }
            """#
        let expected = """
            enum Routes {
                static let home = 1

                #linkerSetRecord(kind: 0x726F7574, storing: Self.home)

                @_silgen_name("$linkerset_kind_726F7574_key__2Fhome") @used nonisolated static func __macro_local_18linkerSetUniqueKeyfMu_() {
                }
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("@LinkerSetEntry refuses a uniqueKey: that isn't a string literal, at the argument")
    func entryUniqueKeyNotLiteral() {
        let source = """
            let path = "/home"
            @LinkerSetEntry(kind: 0x726F_7574, uniqueKey: path)
            let home = 1
            """
        let expected = """
            let path = "/home"
            let home = 1
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'@LinkerSetEntry' needs its unique key as a string literal without interpolation, such as 'uniqueKey: \"/home\"'", line: 2, column: 47)],
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("@LinkerSetEntry refuses a uniqueKey: with an interpolation")
    func entryUniqueKeyInterpolated() {
        let source = #"""
            @LinkerSetEntry(kind: 0x726F_7574, uniqueKey: "/\(1)")
            let home = 1
            """#
        let expected = """
            let home = 1
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'@LinkerSetEntry' needs its unique key as a string literal without interpolation, such as 'uniqueKey: \"/home\"'", line: 1, column: 47)],
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("@LinkerSetEntry refuses an empty uniqueKey: at the attribute")
    func entryUniqueKeyEmpty() {
        let source = """
            @LinkerSetEntry(kind: 0x726F_7574, uniqueKey: "")
            let home = 1
            """
        let expected = """
            let home = 1
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'@LinkerSetEntry' needs a unique key that isn't empty", line: 1, column: 1)],
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    #if canImport(SwiftSyntax600)
    // Before swift-syntax 600 a macro can't see the type around a member, so a private one goes
    // unseen there.
    @Test("A key inside a private type is refused, since its symbol would be local to the file")
    func keyInPrivateTypeRefused() {
        let source = """
            private enum Routes {
                @Keyed("home")
                static let home = 1
            }
            """
        let expected = """
            private enum Routes {
                static let home = 1
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'@Keyed' can't check its unique key inside a private or fileprivate type: the symbol that checks it would be local to the file; make the enclosing type internal or wider", line: 2, column: 5)],
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A key in a type nested inside a fileprivate extension is refused")
    func keyInFileprivateExtensionRefused() {
        let source = """
            fileprivate extension Routes {
                enum Admin {
                    @Keyed("admin")
                    static let admin = 1
                }
            }
            """
        let expected = """
            fileprivate extension Routes {
                enum Admin {
                    static let admin = 1
                }
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            diagnostics: [DiagnosticSpec(message: "'@Keyed' can't check its unique key inside a private or fileprivate type: the symbol that checks it would be local to the file; make the enclosing type internal or wider", line: 3, column: 9)],
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A private type without a key is accepted, since nothing needs its members' symbols")
    func privateTypeWithoutKey() {
        let source = """
            private enum Routes {
                @Keyed
                static let home = 1
            }
            """
        let expected = """
            private enum Routes {
                static let home = 1

                #linkerSetRecord(kind: 0x6B657964, storing: Self.home)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["Keyed": MacroSpec(type: KeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
    #endif

    @Test("Any key's symbol holds only letters, digits and underscores, and decodes back to the key", .tags(.randomized))
    func everyKeyEncodesReversibly() async {
        let key = Gen.character(in: "\u{0}" ... "\u{D7FF}").string(of: 1 ... 24)

        await propertyCheck(count: 300, input: key) { key in
            let declaration: DeclSyntax = "@Keyed(\(literal: key)) struct S {}"
            let attribute = try #require(declaration.as(StructDeclSyntax.self)?.attributes.first?.as(AttributeSyntax.self))
            let prefix = "@_silgen_name(\"$linkerset_kind_6B657964_key_"

            let peers = try KeyedMacro.expansion(of: attribute, providingPeersOf: declaration, in: BasicMacroExpansionContext())

            let function = try #require(peers.last?.trimmedDescription)
            let start = try #require(function.range(of: prefix)?.upperBound)
            let end = try #require(function[start...].firstIndex(of: "\""))
            let actual = function[start ..< end]
            // The naive reference: read the name back a character at a time.
            var bytes: [UInt8] = []
            var index = actual.startIndex
            while index < actual.endIndex {
                if actual[index] == "_" {
                    let next = try #require(actual.index(index, offsetBy: 3, limitedBy: actual.endIndex))
                    bytes.append(try #require(UInt8(actual[actual.index(after: index) ..< next], radix: 16)))
                    index = next
                } else {
                    bytes.append(try #require(actual[index].asciiValue))
                    index = actual.index(after: index)
                }
            }
            #expect(actual.allSatisfy { $0 == "_" || ($0.isASCII && ($0.isLetter || $0.isNumber)) })
            #expect(String(decoding: bytes, as: UTF8.self) == key)
        }
    }
}
