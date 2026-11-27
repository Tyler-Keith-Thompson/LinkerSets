// The record's layout is the ABI every compiled module writes into the section, so these tests
// pin it byte for byte. Each test is self-contained: nothing here is shared but the imports.

import LinkerSets
import Testing

@Suite("LinkerSetRecord: layout")
struct LinkerSetRecordLayoutTests {
    #if _pointerBitWidth(_64)
    @Test("A record is 32 bytes, 8-aligned, where pointers are 64 bits")
    func layout64() {
        let expectedSize = 32
        let expectedStride = 32
        let expectedAlignment = 8

        #expect(MemoryLayout<LinkerSetRecord>.size == expectedSize)
        #expect(MemoryLayout<LinkerSetRecord>.stride == expectedStride)
        #expect(MemoryLayout<LinkerSetRecord>.alignment == expectedAlignment)
        #expect(MemoryLayout<LinkerSetRecord.Literal>.size == expectedSize)
        #expect(MemoryLayout<LinkerSetRecord.Literal>.stride == expectedStride)
        #expect(MemoryLayout<LinkerSetRecord.Literal>.alignment == expectedAlignment)
    }

    @Test("Fields sit at 0, 8 and 16 where pointers are 64 bits")
    func offsets64() {
        let expectedKind: Int? = 0
        let expectedAccessor: Int? = 8
        let expectedContext: Int? = 16

        #expect(MemoryLayout<LinkerSetRecord>.offset(of: \.kind) == expectedKind)
        #expect(MemoryLayout<LinkerSetRecord>.offset(of: \.accessor) == expectedAccessor)
        #expect(MemoryLayout<LinkerSetRecord>.offset(of: \.context) == expectedContext)
    }
    #elseif _pointerBitWidth(_32)
    @Test("A record is 20 bytes, 4-aligned, where pointers are 32 bits")
    func layout32() {
        let expectedSize = 20
        let expectedStride = 20
        let expectedAlignment = 4

        #expect(MemoryLayout<LinkerSetRecord>.size == expectedSize)
        #expect(MemoryLayout<LinkerSetRecord>.stride == expectedStride)
        #expect(MemoryLayout<LinkerSetRecord>.alignment == expectedAlignment)
        #expect(MemoryLayout<LinkerSetRecord.Literal>.size == expectedSize)
        #expect(MemoryLayout<LinkerSetRecord.Literal>.stride == expectedStride)
        #expect(MemoryLayout<LinkerSetRecord.Literal>.alignment == expectedAlignment)
    }

    @Test("Fields sit at 0, 8 and 12 where pointers are 32 bits")
    func offsets32() {
        let expectedKind: Int? = 0
        let expectedAccessor: Int? = 8
        let expectedContext: Int? = 12

        #expect(MemoryLayout<LinkerSetRecord>.offset(of: \.kind) == expectedKind)
        #expect(MemoryLayout<LinkerSetRecord>.offset(of: \.accessor) == expectedAccessor)
        #expect(MemoryLayout<LinkerSetRecord>.offset(of: \.context) == expectedContext)
    }
    #endif

    @Test("A literal's bytes read back as a record with the same kind, context and accessor")
    func literalReadsAsRecord() throws {
        let literal: LinkerSetRecord.Literal = (0x726F_7574, 0, { outValue, _, _, _ in
            outValue.storeBytes(of: 42, as: Int.self)
            return true
        }, 7, 0)
        let expectedKind = LinkerSetKind(rawValue: 0x726F_7574)
        let expectedContext: UInt = 7
        let expectedValue = 42

        let actual = withUnsafeBytes(of: literal) { $0.load(as: LinkerSetRecord.self) }

        #expect(actual.kind == expectedKind)
        #expect(actual.context == expectedContext)
        let accessor = try #require(actual.accessor)
        var value = 0
        let produced = withUnsafeMutablePointer(to: &value) { outValue in
            withUnsafePointer(to: Int.self) { type in
                accessor(UnsafeMutableRawPointer(outValue), UnsafeRawPointer(type), nil, 0)
            }
        }
        #expect(produced)
        #expect(value == expectedValue)
    }

    @Test("A literal's reserved words are zero in its bytes")
    func reservedWordsAreZero() {
        let literal: LinkerSetRecord.Literal = (0xFFFF_FFFF, 0, { _, _, _, _ in false }, UInt.max, 0)
        let reserved1Offset = 4
        let reserved2Offset = 8 + 2 * MemoryLayout<UInt>.size
        let expected: UInt = 0

        let actual = withUnsafeBytes(of: literal) { bytes in
            UInt(bytes.load(fromByteOffset: reserved1Offset, as: UInt32.self))
                | bytes.load(fromByteOffset: reserved2Offset, as: UInt.self)
        }

        #expect(actual == expected)
    }

    @Test("Zeroed bytes read as a slot with no record: kind 0, no accessor, context 0")
    func zeroedSlot() {
        let bytes = [UInt8](repeating: 0, count: MemoryLayout<LinkerSetRecord>.size)
        let expectedKind = LinkerSetKind(rawValue: 0)
        let expectedContext: UInt = 0

        let actual = bytes.withUnsafeBytes { $0.load(as: LinkerSetRecord.self) }

        #expect(actual.kind == expectedKind)
        #expect(actual.accessor == nil)
        #expect(actual.context == expectedContext)
    }

    @Test("Records sit back to back: the second of two literals starts one stride in")
    func backToBack() {
        let records: (LinkerSetRecord.Literal, LinkerSetRecord.Literal) = (
            (1, 0, { _, _, _, _ in false }, 10, 0),
            (2, 0, { _, _, _, _ in false }, 20, 0)
        )
        let expected = [LinkerSetKind(rawValue: 1), LinkerSetKind(rawValue: 2)]

        let actual = withUnsafeBytes(of: records) { bytes in
            [0, 1].map { bytes.load(fromByteOffset: $0 * MemoryLayout<LinkerSetRecord>.stride, as: LinkerSetRecord.self).kind }
        }

        #expect(actual == expected)
    }
}
