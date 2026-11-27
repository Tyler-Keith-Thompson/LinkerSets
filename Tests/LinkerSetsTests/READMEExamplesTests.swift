// The README's examples, verbatim, so the README cannot drift from the code.

#if objectFormat(MachO) || objectFormat(ELF)
import LinkerSets
import Testing

struct Route: Sendable {
    var path: String
}

enum Routes {
    @LinkerSetEntry(kind: 0x726F_7574)  // "rout"
    static let home = Route(path: "/")

    @LinkerSetEntry(kind: 0x726F_7574)
    static let settings = Route(path: "/settings")
}

@Suite("README examples")
struct READMEExamplesTests {
    @Test("Usage")
    func usage() {
        let paths = LinkerSet<Route>(kind: LinkerSetKind(rawValue: 0x726F_7574)).values.map(\.path)
        // "/" and "/settings", in link order
        #expect(paths.sorted() == ["/", "/settings"])
    }
}
#endif
