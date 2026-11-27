// Records declared with a unique key, read like any other: the function that stands for the key
// sits beside the record and changes nothing it holds. Kind "lsuk" belongs to this file alone.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
import ExampleEvents
import LinkerSets
import Testing

// Internal, not private: a private type's members can't take a unique key.
enum KeyedRoutes {
    @LinkerSetEntry(kind: 0x6C73_756B, uniqueKey: "/home")
    static let home = "/home"

    @LinkerSetEntry(kind: 0x6C73_756B, uniqueKey: "/about")
    static func about() -> String { "/about" }
}

@LinkerSetEntry(kind: 0x6C73_756B, uniqueKey: "/contact")
let contactRoute = "/contact"

@Suite("Unique keys: records")
struct UniqueKeyRecordTests {
    @Test("Records with unique keys are found like any other, at file scope and in a type")
    func keyedRecordsAreRead() {
        let sut = LinkerSet<String>(kind: LinkerSetKind(rawValue: 0x6C73_756B))
        let expected = ["/contact", "/home"]

        let actual = sut.values.sorted()

        #expect(actual == expected)
    }

    @Test("A keyed function's record holds the function")
    func keyedFunctionIsRead() {
        let sut = LinkerSet<() -> String>(kind: LinkerSetKind(rawValue: 0x6C73_756B))
        let expected = ["/about"]

        let actual = sut.values.map { $0() }

        #expect(actual == expected)
    }

    @Test("Events keyed by their names are all read")
    func keyedEventsAreRead() {
        let expected = ["login", "logout", "purchase", "refund"]

        let actual = AnalyticsEvents.all.map { $0.name }.sorted()

        #expect(actual == expected)
    }
}
#endif
