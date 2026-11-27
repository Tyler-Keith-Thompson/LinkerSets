// The walk over a section the linker may pad between contributions (COFF), on bytes built by hand,
// so it runs on every platform. Each test is self-contained and builds its own bytes.

@testable import LinkerSetsRuntime
import LinkerSetsTestSupport
import PropertyBased
import Testing

@Suite("LinkerSetSection: padded sections")
struct LinkerSetPaddedSectionTests {
    @Test("Records back to back, with no padding, all read back in order")
    func noPadding() {
        let records: (LinkerSetRecord.Literal, LinkerSetRecord.Literal) = (
            (1, 0, { _, _, _, _ in false }, 10, 0),
            (2, 0, { _, _, _, _ in false }, 20, 0)
        )
        let expected: [UInt] = [10, 20]

        let actual = withUnsafeBytes(of: records) { LinkerSetSection.records(skippingPadding: $0) }

        #expect(actual.map(\.context) == expected)
    }

    @Test("Zero padding of one, two or three alignments between two records is skipped", arguments: [1, 2, 3])
    func paddingBetween(words: Int) {
        let first: LinkerSetRecord.Literal = (1, 0, { _, _, _, _ in false }, 10, 0)
        let second: LinkerSetRecord.Literal = (2, 0, { _, _, _, _ in false }, 20, 0)
        var bytes = withUnsafeBytes(of: first) { [UInt8]($0) }
        bytes += [UInt8](repeating: 0, count: words * MemoryLayout<LinkerSetRecord>.alignment)
        withUnsafeBytes(of: second) { bytes += $0 }
        let expected: [UInt] = [10, 20]

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(skippingPadding: $0) }

        #expect(actual.map(\.context) == expected)
    }

    @Test("Padding before the first record and after the last is skipped")
    func leadingAndTrailingPadding() {
        let record: LinkerSetRecord.Literal = (1, 0, { _, _, _, _ in false }, 10, 0)
        let alignment = MemoryLayout<LinkerSetRecord>.alignment
        let bytes = [UInt8](repeating: 0, count: 2 * alignment)
            + withUnsafeBytes(of: record) { [UInt8]($0) }
            + [UInt8](repeating: 0, count: 5 * alignment)
        let expected: [UInt] = [10]

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(skippingPadding: $0) }

        #expect(actual.map(\.context) == expected)
    }

    @Test("An empty section, an all-zero one, and one shorter than a record hold no records", arguments: [0, 7, 64])
    func noRecords(count: Int) {
        let bytes = [UInt8](repeating: 0, count: count)

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(skippingPadding: $0) }

        #expect(actual.isEmpty)
    }

    @Test("A record cut short at the section's end is left out")
    func truncatedRecord() {
        let records: (LinkerSetRecord.Literal, LinkerSetRecord.Literal) = (
            (1, 0, { _, _, _, _ in false }, 10, 0),
            (2, 0, { _, _, _, _ in false }, 20, 0)
        )
        let bytes = withUnsafeBytes(of: records) { [UInt8]($0).dropLast(1) }
        let expected: [UInt] = [10]

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(skippingPadding: $0) }

        #expect(actual.map(\.context) == expected)
    }

    @Test("Any records with any padding between them read back as the records, in order", .tags(.randomized))
    func anyPadding() async {
        let paddings = Gen<Int>.int(in: 0 ... 4).array(of: 0 ... 16)
        await propertyCheck(count: 100, input: paddings) { paddings in
            let alignment = MemoryLayout<LinkerSetRecord>.alignment
            var bytes: [UInt8] = []
            var expected: [UInt] = []
            for (index, words) in paddings.enumerated() {
                bytes += [UInt8](repeating: 0, count: words * alignment)
                let record: LinkerSetRecord.Literal = (UInt32(index + 1), 0, { _, _, _, _ in false }, UInt(index), 0)
                withUnsafeBytes(of: record) { bytes += $0 }
                expected.append(UInt(index))
            }

            let actual = bytes.withUnsafeBytes { LinkerSetSection.records(skippingPadding: $0) }

            #expect(actual.map(\.context) == expected)
        }
    }
}
