// Records and sections built by hand to fail: each failure is a typed error or is skipped as
// documented, never a trap. Each test is self-contained.

@testable import LinkerSets
import LinkerSetsTestSupport
import PropertyBased
import Testing

@Suite("LinkerSetRecord: failures")
struct LinkerSetRecordFailureTests {
    @Test("A record asked for a type its accessor declines throws typeMismatch")
    func typeMismatch() {
        let literal: LinkerSetRecord.Literal = (0x6C73_6631, 0, { outValue, type, _, _ in
            LinkerSetRecord.__store(42, into: outValue, ifAsked: type)
        }, 0, 0)
        let sut = withUnsafeBytes(of: literal) { $0.load(as: LinkerSetRecord.self) }

        #expect(throws: LinkerSetRecord.ValueError.typeMismatch) {
            try sut.value(as: String.self)
        }
    }

    @Test("The same record asked for its own type produces its value")
    func matchingType() throws {
        let literal: LinkerSetRecord.Literal = (0x6C73_6631, 0, { outValue, type, _, _ in
            LinkerSetRecord.__store(42, into: outValue, ifAsked: type)
        }, 0, 0)
        let sut = withUnsafeBytes(of: literal) { $0.load(as: LinkerSetRecord.self) }
        let expected = 42

        let actual = try sut.value(as: Int.self)

        #expect(actual == expected)
    }

    @Test("A zeroed slot, with no accessor, throws emptySlot")
    func emptySlot() {
        let zeroes = [UInt8](repeating: 0, count: MemoryLayout<LinkerSetRecord>.stride)
        let sut = zeroes.withUnsafeBytes { $0.load(as: LinkerSetRecord.self) }

        #expect(throws: LinkerSetRecord.ValueError.emptySlot) {
            try sut.value(as: Int.self)
        }
    }

    @Test("A record with a reserved field set is of an unknown version and throws unsupportedVersion", arguments: [
        (UInt32(1), UInt(0)), (UInt32(0), UInt(1)), (UInt32.max, UInt.max),
    ])
    func unsupportedVersion(reserved1: UInt32, reserved2: UInt) {
        let literal: LinkerSetRecord.Literal = (0x6C73_6631, reserved1, { outValue, type, _, _ in
            LinkerSetRecord.__store(42, into: outValue, ifAsked: type)
        }, 0, reserved2)
        let sut = withUnsafeBytes(of: literal) { $0.load(as: LinkerSetRecord.self) }

        #expect(!sut.isSupportedVersion)
        #expect(throws: LinkerSetRecord.ValueError.unsupportedVersion) {
            try sut.value(as: Int.self)
        }
    }

    @Test("A record with zero reserved fields is of the supported version")
    func supportedVersion() {
        let literal: LinkerSetRecord.Literal = (0x6C73_6631, 0, { _, _, _, _ in false }, 7, 0)

        let actual = withUnsafeBytes(of: literal) { $0.load(as: LinkerSetRecord.self) }

        #expect(actual.isSupportedVersion)
    }
}

@Suite("LinkerSetSection: malformed contents")
struct LinkerSetSectionContentsTests {
    @Test("An empty section holds no records")
    func emptySection() {
        let bytes: [UInt8] = []

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(in: $0) }

        #expect(actual.isEmpty)
    }

    @Test("A section shorter than one record holds none")
    func shorterThanARecord() {
        let bytes = [UInt8](repeating: 0xFF, count: MemoryLayout<LinkerSetRecord>.stride - 1)

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(in: $0) }

        #expect(actual.isEmpty)
    }

    @Test("A truncated section is read up to its last whole record")
    func truncated() {
        let literals: [LinkerSetRecord.Literal] = [
            (1, 0, { _, _, _, _ in false }, 10, 0),
            (2, 0, { _, _, _, _ in false }, 20, 0),
        ]
        let stride = MemoryLayout<LinkerSetRecord>.stride
        let bytes = literals.withUnsafeBytes { [UInt8]($0) } + [UInt8](repeating: 0xFF, count: stride / 2)
        let expected: [UInt] = [10, 20]

        let actual = bytes.withUnsafeBytes { LinkerSetSection.records(in: $0) }.map(\.context)

        #expect(actual == expected)
    }

    @Test("A section that starts off a record's alignment reads its records without trapping")
    func misaligned() {
        let literals: [LinkerSetRecord.Literal] = [
            (1, 0, { _, _, _, _ in false }, 10, 0),
            (2, 0, { _, _, _, _ in false }, 20, 0),
        ]
        let shifted = [UInt8(0)] + literals.withUnsafeBytes { [UInt8]($0) }
        let expected: [UInt] = [10, 20]

        let actual = shifted.withUnsafeBytes { bytes in
            LinkerSetSection.records(in: UnsafeRawBufferPointer(rebasing: bytes.dropFirst()))
        }.map(\.context)

        #expect(actual == expected)
    }

    @Test("Any whole records followed by any partial one read back as the whole records", .tags(.randomized))
    func wholeRecordsOnly() async {
        let stride = MemoryLayout<LinkerSetRecord>.stride
        let count = Gen<Int>.int(in: 0 ... 32)
        let trailing = Gen<Int>.int(in: 0 ... stride - 1)
        await propertyCheck(count: 100, input: count, trailing) { count, trailing in
            let literals: [LinkerSetRecord.Literal] = (0 ..< count).map { index in
                (UInt32(index), 0, { _, _, _, _ in false }, UInt(index), 0)
            }
            let bytes = literals.withUnsafeBytes { [UInt8]($0) } + [UInt8](repeating: 0xAB, count: trailing)
            let expected = (0 ..< count).map { UInt($0) }

            let actual = bytes.withUnsafeBytes { LinkerSetSection.records(in: $0) }.map(\.context)

            #expect(actual == expected)
        }
    }
}
