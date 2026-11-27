// The README's examples, verbatim, so the README cannot drift from the code.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
import LinkerSets
import Testing

struct DebugMenuItem: Sendable {
    var title: String
}

extension LinkerSetKind {
    static let debugMenu = LinkerSetKind(rawValue: 0x6D65_6E75)  // "menu"
}

// In the networking module:
enum NetworkDebugging {
    @LinkerSetEntry(kind: 0x6D65_6E75)
    static let clearCache = DebugMenuItem(title: "Clear cache")
}

// In the accounts module:
enum AccountDebugging {
    @LinkerSetEntry(kind: 0x6D65_6E75)
    static let signOut = DebugMenuItem(title: "Sign out")
}

@Suite("README examples")
struct READMEExamplesTests {
    @Test("Usage")
    func usage() {
        let items = LinkerSet<DebugMenuItem>(kind: .debugMenu).values
        // Both items, in the order the linker laid them out. Sort them if order matters.
        #expect(items.map(\.title).sorted() == ["Clear cache", "Sign out"])
    }

    @Test("Deriving a kind from four letters")
    func kindFromLetters() {
        let kind = "menu".utf8.reduce(0) { $0 << 8 | UInt32($1) }
        #expect(kind == 0x6D65_6E75)
    }
}
#endif
