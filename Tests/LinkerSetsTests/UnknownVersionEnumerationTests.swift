// A record written by hand as a newer layout would write it, with reserved1 set, in the real
// section: enumeration skips it rather than call an accessor whose contract it doesn't know. Kind
// "lsv1" belongs to this file alone.

#if objectFormat(MachO) || objectFormat(ELF)
@testable import LinkerSets
import Testing

#if objectFormat(MachO)
@section("__DATA_CONST,__linker_sets")
#elseif objectFormat(ELF)
@section("linker_sets")
#endif
@used private let newerLayoutRecord: LinkerSetRecord.Literal = (0x6C73_7631, 1, { outValue, type, _, _ in
    LinkerSetRecord.__store(42, into: outValue, ifAsked: type)
}, 0, 0)

@Suite("LinkerSet: records of an unknown version")
struct UnknownVersionEnumerationTests {
    @Test("A set skips a record whose reserved fields aren't zero, though the section holds it")
    func skipsUnknownVersion() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_7631))
        let expectedInSection = 1

        let inSection = LinkerSetSection.records().filter { $0.kind.rawValue == 0x6C73_7631 }

        #expect(inSection.count == expectedInSection)
        #expect(sut.records.isEmpty)
        #expect(sut.values.isEmpty)
    }
}
#endif
