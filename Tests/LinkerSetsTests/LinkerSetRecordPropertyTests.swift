// Property tests against a naive reference: the record's fields read from the bytes at the
// offsets the layout table documents, whatever the values. Each test is self-contained.

import Generators
import LinkerSets
import LinkerSetsTestSupport
import PropertyBased
import Sampling
import Testing

@Suite("LinkerSetRecord: properties")
struct LinkerSetRecordPropertyTests {
    @Test("Any kind and context read back from a literal's bytes at the documented offsets", .tags(.randomized))
    func fieldsAtDocumentedOffsets() async {
        let kind = Gen<UInt32>.value(in: UInt32.min ... UInt32.max)
        let context = Gen<UInt>.value(in: UInt.min ... UInt.max)
        await propertyCheck(count: 500, input: kind, context) { kind, context in
            let literal: LinkerSetRecord.Literal = (kind, 0, { _, _, _, _ in false }, context, 0)
            // kind, a reserved UInt32, then a pointer.
            let contextOffset = 4 + 4 + MemoryLayout<UnsafeRawPointer>.size

            let actual = withUnsafeBytes(of: literal) { $0.load(as: LinkerSetRecord.self) }
            let expected = withUnsafeBytes(of: literal) { bytes in
                (kind: bytes.load(fromByteOffset: 0, as: UInt32.self),
                 context: bytes.load(fromByteOffset: contextOffset, as: UInt.self))
            }

            #expect(actual.kind.rawValue == expected.kind)
            #expect(actual.context == expected.context)
            #expect(actual.kind.rawValue == kind)
            #expect(actual.context == context)
        }
    }

    @Test("A seeded run of records read back in place keeps every record's kind and context", .tags(.randomized))
    func seededRun() {
        var generator = Xoshiro256StarStar(seed: 42)
        let count = generator.integer(in: 1 ... 64)
        let literals: [LinkerSetRecord.Literal] = (0 ..< count).map { _ in
            (UInt32(truncatingIfNeeded: generator.integer(in: 0 ... Int(Int32.max))), 0, { _, _, _, _ in false },
             UInt(truncatingIfNeeded: generator.integer(in: 0 ... Int(Int32.max))), 0)
        }
        let expected = literals.map { [UInt($0.kind), $0.context] }

        let actual = literals.withUnsafeBytes { bytes in
            (0 ..< count).map { index in
                let record = bytes.load(fromByteOffset: index * MemoryLayout<LinkerSetRecord>.stride, as: LinkerSetRecord.self)
                return [UInt(record.kind.rawValue), record.context]
            }
        }

        #expect(actual == expected)
    }
}
