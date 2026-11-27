// Each test is self-contained: nothing here is shared but the imports.

import LinkerSets
import LinkerSetsTestSupport
import Testing

@Suite("LinkerSetKind")
struct LinkerSetKindTests {
    @Test("A kind holds the raw value it was made from")
    func rawValue() {
        let expected: UInt32 = 0x7465_7374

        let actual = LinkerSetKind(rawValue: expected).rawValue

        #expect(actual == expected)
    }

    @Test("A kind is four bytes, so it fills a record's first word", arguments: [UInt32.min, 1, UInt32.max])
    func boundaries(rawValue: UInt32) {
        let expectedSize = 4

        let actual = withUnsafeBytes(of: LinkerSetKind(rawValue: rawValue)) { $0.load(as: UInt32.self) }

        #expect(MemoryLayout<LinkerSetKind>.size == expectedSize)
        #expect(actual == rawValue)
    }

    @Test("Kinds are equal, and hash equally, exactly when their raw values are", .tags(.conformance))
    func equality() {
        let routes = LinkerSetKind(rawValue: 0x726F_7574)
        let sameRoutes = LinkerSetKind(rawValue: 0x726F_7574)
        let tests = LinkerSetKind(rawValue: 0x7465_7374)

        let actual: Set = [routes, sameRoutes, tests]

        #expect(routes == sameRoutes)
        #expect(routes.hashValue == sameRoutes.hashValue)
        #expect(routes != tests)
        #expect(actual.count == 2)
    }
}
