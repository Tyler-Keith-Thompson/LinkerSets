// The README's examples, verbatim, so the README cannot drift from the code.

import LinkerSets
import Testing

extension LinkerSetKind {
    /// Records of routes, `"rout"`.
    static let routes = LinkerSetKind(rawValue: 0x726F_7574)
}

@Suite("README examples")
struct READMEExamplesTests {
    @Test("Usage")
    func usage() {
        let size = MemoryLayout<LinkerSetRecord>.size
        #expect(LinkerSetKind.routes.rawValue == 0x726F_7574)
        #if _pointerBitWidth(_64)
        #expect(size == 32)
        #endif
    }
}
