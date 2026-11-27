// Records of static members of a class and an actor, found again at run time. Kind "lscm" belongs
// to this file alone.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
import LinkerSets
import Testing

final class ClassMemberScheduler {
    @LinkerSetEntry(kind: 0x6C73_636D)
    static func start() -> String { "class start" }

    @LinkerSetEntry(kind: 0x6C73_636D)
    static let label = "class label"
}

class ClassMemberBase {
    @LinkerSetEntry(kind: 0x6C73_636D)
    static func reset() -> String { "base reset" }
}

actor ClassMemberWorker {
    @LinkerSetEntry(kind: 0x6C73_636D)
    static func run() -> String { "actor run" }
}

extension ClassMemberBase {
    enum Jobs {
        @LinkerSetEntry(kind: 0x6C73_636D)
        static func clean() -> String { "nested clean" }
    }
}

@Suite("Members of classes and actors: enumeration")
struct ClassMemberEnumerationTests {
    @Test("Static functions of a class, a non-final class, an actor and a type nested in a class's extension are found")
    func staticFunctions() {
        let sut = LinkerSet<() -> String>(kind: LinkerSetKind(rawValue: 0x6C73_636D))
        let expected = ["actor run", "base reset", "class start", "nested clean"]

        let actual = sut.values.map { $0() }.sorted()

        #expect(actual == expected)
    }

    @Test("A class's static property is found")
    func staticProperty() {
        let sut = LinkerSet<String>(kind: LinkerSetKind(rawValue: 0x6C73_636D))
        let expected = ["class label"]

        let actual = sut.values

        #expect(actual == expected)
    }
}
#endif
