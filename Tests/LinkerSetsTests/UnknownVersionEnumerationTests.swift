// A record written by hand as a newer layout would write it, with reserved1 set, in the real
// section: enumeration skips it rather than call an accessor whose contract it doesn't know. Kind
// "lsv1" belongs to this file alone.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
@testable import LinkerSetsRuntime
import Testing

#if objectFormat(MachO)
@section("__DATA_CONST,__linker_sets") @used
private let newerLayoutRecord: LinkerSetRecord.Literal = (0x6C73_7631, 1, { outValue, type, _, _ in
    LinkerSetRecord.__store(42, into: outValue, ifAsked: type)
}, 0, 0)
#elseif objectFormat(ELF) && _pointerBitWidth(_64)
// The note around the record, as LinkerSetRecord.Note documents: name "LinkerSets", type 1, and
// the record's size, 32 bytes where pointers are 64 bits and 20 where they are 32.
@section(".note.linker_sets") @used
private let newerLayoutRecord: LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x6C73_7631, 1, { outValue, type, _, _ in
    LinkerSetRecord.__store(42, into: outValue, ifAsked: type)
}, 0, 0))
#elseif objectFormat(ELF) && _pointerBitWidth(_32)
@section(".note.linker_sets") @used
private let newerLayoutRecord: LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), (0x6C73_7631, 1, { outValue, type, _, _ in
    LinkerSetRecord.__store(42, into: outValue, ifAsked: type)
}, 0, 0))
#elseif objectFormat(Wasm)
@section("linker_sets") @used
private let newerLayoutRecord: LinkerSetRecord.Literal = (0x6C73_7631, 1, { outValue, type, _, _ in
    LinkerSetRecord.__store(42, into: outValue, ifAsked: type)
}, 0, 0)
#elseif objectFormat(COFF)
@section(".lnkset$M") @used
private let newerLayoutRecord: LinkerSetRecord.Literal = (0x6C73_7631, 1, { outValue, type, _, _ in
    LinkerSetRecord.__store(42, into: outValue, ifAsked: type)
}, 0, 0)
#endif

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
