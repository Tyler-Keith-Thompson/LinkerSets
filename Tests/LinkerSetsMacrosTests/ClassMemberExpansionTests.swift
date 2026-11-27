// Records of static members of classes and actors, where `Self` is covariant and can't appear in
// the record's stored initializer: the record names the enclosing type instead, qualified through
// every scope around it. Each test is self-contained.

import LinkerSetsMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

#if canImport(SwiftSyntax600)
// Before swift-syntax 600 a macro can't see the type around a member, so it writes `Self`.
@Suite("Members of classes and actors: expansions")
struct ClassMemberExpansionTests {
    @Test("A class's static function is stored through the class's name")
    func classStaticFunction() {
        let source = """
            class Scheduler {
                @LinkerSetEntry(kind: 0x6A6F_6273)
                static func start() {}
            }
            """
        let expected = """
            class Scheduler {
                static func start() {}

                #linkerSetRecord(kind: 0x6A6F6273, storing: Scheduler.start as () -> Void)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("An actor's static property is stored through the actor's name")
    func actorStaticProperty() {
        let source = """
            actor Worker {
                @LinkerSetEntry(kind: 0x6A6F_6273)
                static let name = "worker"
            }
            """
        let expected = """
            actor Worker {
                static let name = "worker"

                #linkerSetRecord(kind: 0x6A6F6273, storing: Worker.name)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test("A member of a type nested in a class names every enclosing type, outermost first")
    func nestedInClass() {
        let source = """
            class Scheduler {
                enum Jobs {
                    @LinkerSetEntry(kind: 0x6A6F_6273)
                    static func clean() {}
                }
            }
            """
        let expected = """
            class Scheduler {
                enum Jobs {
                    static func clean() {}

                    #linkerSetRecord(kind: 0x6A6F6273, storing: Scheduler.Jobs.clean as () -> Void)
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

    @Test("A member of a class's extension names the extended type, as written")
    func classExtension() {
        let source = """
            extension Jobs.Scheduler {
                @LinkerSetEntry(kind: 0x6A6F_6273)
                static func stop() {}
            }
            """
        let expected = """
            extension Jobs.Scheduler {
                static func stop() {}

                #linkerSetRecord(kind: 0x6A6F6273, storing: Jobs.Scheduler.stop as () -> Void)
            }
            """

        assertMacroExpansion(
            source,
            expandedSource: expected,
            macroSpecs: ["LinkerSetEntry": MacroSpec(type: LinkerSetEntryMacro.self)],
            failureHandler: { Issue.record("\($0.message)") }
        )
    }
}
#endif
