// Records declared with @LinkerSetEntry, found again by each object format's reader. Kinds
// "lsa1" through "lsa4" belong to this file alone; each test reads the records itself.

#if objectFormat(MachO) || objectFormat(ELF)
import Generators
@testable import LinkerSets
import LinkerSetsTestSupport
import PropertyBased
import Sampling
import Testing

private enum EnumerationFixtures {
    @LinkerSetEntry(kind: 0x6C73_6131)
    static let first = 1

    @LinkerSetEntry(kind: 0x6C73_6131)
    static let second = 2

    // Of kind "lsa1" but a String, so a set of Ints skips its value.
    @LinkerSetEntry(kind: 0x6C73_6131)
    static let label = "not an Int"

    @LinkerSetEntry(kind: 0x6C73_6132)
    static let other = 100

    @LinkerSetEntry(kind: 0x6C73_6133)
    static func triple(_ value: Int) -> Int { value * 3 }
}

@LinkerSetEntry(kind: 0x6C73_6133)
private func double(_ value: Int) -> Int { value * 2 }

// Types of kind "lsa4"; @LinkerSetEntry requires no protocol of them. At file scope, because
// before swift-syntax 600 a macro can't see whether a type is nested.
@LinkerSetEntry(kind: 0x6C73_6134)
private struct FirstPlugin {}

@LinkerSetEntry(kind: 0x6C73_6134)
private final class SecondPlugin {}

@Suite("LinkerSet: enumeration")
struct LinkerSetEnumerationTests {
    @Test("Every record of a kind is found, and none of another kind")
    func everyRecordOfItsKind() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_6131))
        let expectedCount = 3

        let actual = sut.records

        #expect(actual.count == expectedCount)
        #expect(actual.allSatisfy { $0.kind.rawValue == 0x6C73_6131 })
    }

    @Test("Values hold what each record produces, leaving out a record of another type")
    func values() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_6131))
        let expected = [1, 2]

        let actual = sut.values

        #expect(actual.sorted() == expected)
    }

    @Test("A set of the other type of the same kind holds that type's record")
    func otherTypeSameKind() {
        let sut = LinkerSet<String>(kind: LinkerSetKind(rawValue: 0x6C73_6131))
        let expected = ["not an Int"]

        let actual = sut.values

        #expect(actual == expected)
    }

    @Test("Another kind's set holds only its own record")
    func otherKind() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_6132))
        let expected = [100]

        let actual = sut.values

        #expect(actual == expected)
    }

    @Test("Static and free functions are found as values of their function type")
    func functions() {
        let sut = LinkerSet<(Int) -> Int>(kind: LinkerSetKind(rawValue: 0x6C73_6133))
        let expected = [10, 15]

        let actual = sut.values.map { $0(5) }

        #expect(actual.sorted() == expected)
    }

    @Test("Types are found as their metatypes, Any.Type, when the macro requires no protocol")
    func types() {
        let sut = LinkerSet<Any.Type>(kind: LinkerSetKind(rawValue: 0x6C73_6134))
        let expected: Set<ObjectIdentifier> = [ObjectIdentifier(FirstPlugin.self), ObjectIdentifier(SecondPlugin.self)]

        let actual = Set(sut.values.map(ObjectIdentifier.init))

        #expect(actual == expected)
    }

    @Test("A kind no record was declared with holds nothing")
    func undeclaredKind() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_6139))

        let actual = sut.records

        #expect(actual.isEmpty)
    }

    @Test("A record asked for a type it doesn't produce gives nil")
    func wrongType() {
        let sut = LinkerSet<Double>(kind: LinkerSetKind(rawValue: 0x6C73_6131))
        let expectedRecordCount = 3

        let actual = sut.values

        #expect(sut.records.count == expectedRecordCount)
        #expect(actual.isEmpty)
    }

    @Test("Kind 0 marks empty slots, so its set is empty")
    func emptySlotKind() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0))

        let actual = sut.records

        #expect(actual.isEmpty)
    }

    @Test("Enumerating twice returns the same records in the same order")
    func deterministic() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_6131))
        let expected = sut.values

        let actual = sut.values

        #expect(actual == expected)
        #expect(sut.records.count == LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_6131)).records.count)
    }

    @Test("A set holds exactly the section's records of its kind, in section order", .tags(.randomized))
    func matchesNaiveFilter() async {
        let kind = Gen.element(of: [0x6C73_6131, 0x6C73_6132, 0x6C73_6133, 0x6C73_6139] as [UInt32]).map { $0! }
        await propertyCheck(count: 50, input: kind) { kind in
            let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: kind))
            var expected: [Int] = []
            for record in LinkerSetSection.records() where record.kind.rawValue == kind && record.accessor != nil {
                if let value = record.value(as: Int.self) { expected.append(value) }
            }

            let actual = sut.values

            #expect(actual == expected)
        }
    }
}
#endif
