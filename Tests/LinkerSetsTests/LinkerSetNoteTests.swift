// The ELF note walker, on note segments built by hand: LinkerSets notes give their records, and
// everything else in a segment is skipped without trapping. ELF only. Each test is self-contained
// and builds its own bytes.

#if objectFormat(ELF)
@testable import LinkerSetsRuntime
import LinkerSetsTestSupport
import PropertyBased
import Testing

@Suite("LinkerSetSection: ELF notes")
struct LinkerSetNoteTests {
    @Test("A LinkerSets note's descriptor reads back as its record")
    func oneRecord() {
        let note: LinkerSetRecord.Note = (11, UInt32(MemoryLayout<LinkerSetRecord>.stride), 1,
                                          (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0),
                                          (0x6C73_6E31, 0, { _, _, _, _ in false }, 7, 0))
        let expectedKind: UInt32 = 0x6C73_6E31
        let expectedContext: UInt = 7

        let actual = withUnsafeBytes(of: note) { bytes in
            LinkerSetSection.records(inNotes: NoteSegment(bytes: bytes, alignment: MemoryLayout<LinkerSetRecord>.alignment))
        }

        #expect(actual.map(\.kind.rawValue) == [expectedKind])
        #expect(actual.map(\.context) == [expectedContext])
    }

    @Test("A GNU note before a LinkerSets note is skipped, in a 4-aligned segment")
    func foreignNoteSkipped() {
        // A GNU build-id note: namesz 4, descsz 8, type 3, "GNU\0", 8 bytes of id.
        var bytes: [UInt8] = []
        for word in [UInt32(4), 8, 3] { withUnsafeBytes(of: word) { bytes += $0 } }
        bytes += Array("GNU".utf8) + [0] + [UInt8](repeating: 0xAB, count: 8)
        let note: LinkerSetRecord.Note = (11, UInt32(MemoryLayout<LinkerSetRecord>.stride), 1,
                                          (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0),
                                          (0x6C73_6E31, 0, { _, _, _, _ in false }, 9, 0))
        withUnsafeBytes(of: note) { bytes += $0 }
        let expectedContexts: [UInt] = [9]

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(inNotes: NoteSegment(bytes: $0, alignment: 4)) }

        #expect(actual.map(\.context) == expectedContexts)
    }

    @Test("A LinkerSets note of another type, or of another descriptor size, is skipped")
    func otherTypeOrSizeSkipped() {
        let stride = UInt32(MemoryLayout<LinkerSetRecord>.stride)
        let otherType: LinkerSetRecord.Note = (11, stride, 2, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0),
                                               (1, 0, { _, _, _, _ in false }, 1, 0))
        let kept: LinkerSetRecord.Note = (11, stride, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0),
                                          (2, 0, { _, _, _, _ in false }, 2, 0))
        // A record of a longer, future layout: its size is stride + 8, its bytes zero.
        var bytes: [UInt8] = []
        for word in [UInt32(11), stride + 8, 1] { withUnsafeBytes(of: word) { bytes += $0 } }
        bytes += Array("LinkerSets".utf8) + [0, 0] + [UInt8](repeating: 0, count: Int(stride) + 8)
        withUnsafeBytes(of: otherType) { bytes += $0 }
        withUnsafeBytes(of: kept) { bytes += $0 }
        let expectedContexts: [UInt] = [2]

        let actual = bytes.withUnsafeBytes {
            LinkerSetSection.records(inNotes: NoteSegment(bytes: $0, alignment: MemoryLayout<LinkerSetRecord>.alignment))
        }

        #expect(actual.map(\.context) == expectedContexts)
    }

    @Test("A note that runs past the segment's end ends the walk without trapping")
    func truncatedNote() {
        let note: LinkerSetRecord.Note = (11, UInt32(MemoryLayout<LinkerSetRecord>.stride), 1,
                                          (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0),
                                          (1, 0, { _, _, _, _ in false }, 1, 0))
        let whole = withUnsafeBytes(of: note) { [UInt8]($0) }
        let bytes = whole + whole.dropLast(4)
        let expectedContexts: [UInt] = [1]

        let actual = bytes.withUnsafeBytes {
            LinkerSetSection.records(inNotes: NoteSegment(bytes: $0, alignment: MemoryLayout<LinkerSetRecord>.alignment))
        }

        #expect(actual.map(\.context) == expectedContexts)
    }

    @Test("An empty segment, or one shorter than a note's header, holds no records", arguments: [0, 11])
    func shortSegment(count: Int) {
        let bytes = [UInt8](repeating: 0xFF, count: count)

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(inNotes: NoteSegment(bytes: $0, alignment: 4)) }

        #expect(actual.isEmpty)
    }

    @Test("A header claiming a huge name or descriptor ends the walk without trapping")
    func hugeSizes() {
        var bytes: [UInt8] = []
        for word in [UInt32.max, UInt32.max, 1] { withUnsafeBytes(of: word) { bytes += $0 } }
        bytes += [UInt8](repeating: 0, count: 64)

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(inNotes: NoteSegment(bytes: $0, alignment: 4)) }

        #expect(actual.isEmpty)
    }

    @Test("Any mix of LinkerSets and GNU notes gives the LinkerSets records, in order", .tags(.randomized))
    func mixedNotes() async {
        let isOurs = Gen<Bool>.bool.array(of: 0 ... 24)
        await propertyCheck(count: 100, input: isOurs) { isOurs in
            let stride = UInt32(MemoryLayout<LinkerSetRecord>.stride)
            let alignment = MemoryLayout<LinkerSetRecord>.alignment
            var bytes: [UInt8] = []
            var expected: [UInt] = []
            for (index, ours) in isOurs.enumerated() {
                if ours {
                    let note: LinkerSetRecord.Note = (11, stride, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0),
                                                      (1, 0, { _, _, _, _ in false }, UInt(index), 0))
                    withUnsafeBytes(of: note) { bytes += $0 }
                    expected.append(UInt(index))
                } else {
                    // A GNU note with an 8-byte descriptor: 24 bytes, a multiple of either alignment.
                    for word in [UInt32(4), 8, 3] { withUnsafeBytes(of: word) { bytes += $0 } }
                    bytes += Array("GNU".utf8) + [0] + [UInt8](repeating: UInt8(index), count: 8)
                }
            }

            let actual = bytes.withUnsafeBytes { LinkerSetSection.records(inNotes: NoteSegment(bytes: $0, alignment: alignment)) }

            #expect(actual.map(\.context) == expected)
        }
    }
}
#endif
