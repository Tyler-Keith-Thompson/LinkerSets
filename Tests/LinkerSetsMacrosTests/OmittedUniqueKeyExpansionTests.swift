// A client that omits a unique key in a private scope rather than refusing it: the record is
// written without the function whose symbol checks the key. Each test is self-contained.

import LinkerSetsMacroSupport
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// `@OmittingKeyed("…")`: a record of kind `"keyd"` whose key is the attribute's string literal,
/// except that a key in a private scope is omitted.
enum OmittingKeyedMacro: LinkerSetMacro {
    static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6B65_7964 }  // "keyd"

    static var uniqueKeyInPrivateScope: UniqueKeyInPrivateScope { .omitted }

    static func uniqueKey(of declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) throws -> String? {
        attribute.arguments?.as(LabeledExprListSyntax.self)?.first?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
    }
}

/// `@RefusingKeyed("…")`: `@OmittingKeyed`'s records, with the default choice.
enum RefusingKeyedMacro: LinkerSetMacro {
    static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6B65_7964 }  // "keyd"

    static func uniqueKey(of declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) throws -> String? {
        attribute.arguments?.as(LabeledExprListSyntax.self)?.first?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
    }
}

@Suite("A unique key omitted in a private scope: expansions")
struct OmittedUniqueKeyExpansionTests {
    @Test("A macro that doesn't choose refuses a key in a private scope")
    func defaultRefuses() {
        let expected = UniqueKeyInPrivateScope.refused

        let actual = RefusingKeyedMacro.uniqueKeyInPrivateScope

        #expect(actual == expected)
    }

    @Test("A key at file scope is kept when the macro omits keys in private scopes")
    func keyAtFileScopeKept() {
        let source = """
            @OmittingKeyed("login")
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
            macroSpecs: ["OmittingKeyed": MacroSpec(type: OmittingKeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    #if canImport(SwiftSyntax600)
    // Before swift-syntax 600 a macro can't see the type around a member, so a private one goes
    // unseen there and its key is written either way.
    @Test("A key inside a private type is omitted, and the record is still written")
    func keyInPrivateTypeOmitted() {
        let source = """
            private enum Routes {
                @OmittingKeyed("home")
                static let home = 1
            }
            """
        let expected = """
            private enum Routes {
                static let home = 1

                #linkerSetRecord(kind: 0x6B657964, storing: Routes.home)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["OmittingKeyed": MacroSpec(type: OmittingKeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A key in a type nested inside a fileprivate extension is omitted")
    func keyInFileprivateExtensionOmitted() {
        let source = """
            fileprivate extension Routes {
                enum Admin {
                    @OmittingKeyed("admin")
                    static let admin = 1
                }
            }
            """
        let expected = """
            fileprivate extension Routes {
                enum Admin {
                    static let admin = 1

                    #linkerSetRecord(kind: 0x6B657964, storing: Routes.Admin.admin)
                }
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["OmittingKeyed": MacroSpec(type: OmittingKeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A key inside an internal type is kept when the macro omits keys in private scopes")
    func keyInInternalTypeKept() {
        let source = """
            enum Routes {
                @OmittingKeyed("home")
                static let home = 1
            }
            """
        let expected = """
            enum Routes {
                static let home = 1

                #linkerSetRecord(kind: 0x6B657964, storing: Routes.home)

                @_silgen_name("$linkerset_kind_6B657964_key_home") @used nonisolated static func __macro_local_18linkerSetUniqueKeyfMu_() {
                }
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["OmittingKeyed": MacroSpec(type: OmittingKeyedMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test(
        "A key is omitted in exactly the scopes where it is refused",
        arguments: [
            (scope: "private enum Routes", isPrivate: true),
            (scope: "fileprivate enum Routes", isPrivate: true),
            (scope: "private extension Routes", isPrivate: true),
            (scope: "fileprivate struct Routes", isPrivate: true),
            (scope: "enum Routes", isPrivate: false),
            (scope: "public enum Routes", isPrivate: false),
            (scope: "internal extension Routes", isPrivate: false),
            (scope: "public extension Routes", isPrivate: false),
        ]
    )
    func omittedWhereRefused(scope: String, isPrivate: Bool) {
        func expand(_ macro: any Macro.Type, inner: String) -> (source: String, diagnostics: Int) {
            let source: SourceFileSyntax = """
                \(raw: scope) {
                    \(raw: inner) {
                        @Keyed("home")
                        static let home = 1
                    }
                }
                """
            let context = BasicMacroExpansionContext()
            let expanded = source.expand(
                macros: ["Keyed": macro],
                contextGenerator: { node in
                    BasicMacroExpansionContext(sharingWith: context, lexicalContext: node.allMacroLexicalContexts())
                }
            )
            return (expanded.description, context.diagnostics.count)
        }
        // The private scope one level out from the member's own type or extension.
        let inners: [String] = ["enum Inner", "struct Inner"]

        for inner in inners {
            let refusing = expand(RefusingKeyedMacro.self, inner: inner)
            let omitting = expand(OmittingKeyedMacro.self, inner: inner)

            #expect((refusing.diagnostics == 1) == isPrivate)
            #expect(omitting.diagnostics == 0)
            #expect(omitting.source.contains("linkerSetUniqueKey") == !isPrivate)
            #expect(omitting.source.contains("#linkerSetRecord"))
        }
    }
    #endif
}
