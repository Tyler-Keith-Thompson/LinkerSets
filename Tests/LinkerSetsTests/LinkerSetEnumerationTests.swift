// Records declared by hand in the section LinkerSets owns, found again by each object format's
// reader; the declarations differ only in the section name the format uses. Kinds "lsa1" and
// "lsa2" belong to this file alone. The records are file-scope globals, as the macros will emit
// them; each test reads them itself.

#if objectFormat(MachO) || objectFormat(ELF)
import Generators
@testable import LinkerSets
import LinkerSetsTestSupport
import PropertyBased
import Sampling
import Testing

#if objectFormat(MachO)
@section("__DATA_CONST,__linker_sets") @used
private let firstRecord: LinkerSetRecord.Literal = (0x6C73_6131, 0, { outValue, type, _, _ in
    guard type.load(as: Any.Type.self) == Int.self else { return false }
    outValue.initializeMemory(as: Int.self, to: 1)
    return true
}, 0, 0)

@section("__DATA_CONST,__linker_sets") @used
private let secondRecord: LinkerSetRecord.Literal = (0x6C73_6131, 0, { outValue, type, _, _ in
    guard type.load(as: Any.Type.self) == Int.self else { return false }
    outValue.initializeMemory(as: Int.self, to: 2)
    return true
}, 2, 0)

@section("__DATA_CONST,__linker_sets") @used
private let decliningRecord: LinkerSetRecord.Literal = (0x6C73_6131, 0, { _, _, _, _ in false }, 3, 0)

@section("__DATA_CONST,__linker_sets") @used
private let otherKindRecord: LinkerSetRecord.Literal = (0x6C73_6132, 0, { outValue, type, _, _ in
    guard type.load(as: Any.Type.self) == Int.self else { return false }
    outValue.initializeMemory(as: Int.self, to: 100)
    return true
}, 100, 0)
#elseif objectFormat(ELF)
@section("linker_sets") @used
private let firstRecord: LinkerSetRecord.Literal = (0x6C73_6131, 0, { outValue, type, _, _ in
    guard type.load(as: Any.Type.self) == Int.self else { return false }
    outValue.initializeMemory(as: Int.self, to: 1)
    return true
}, 0, 0)

@section("linker_sets") @used
private let secondRecord: LinkerSetRecord.Literal = (0x6C73_6131, 0, { outValue, type, _, _ in
    guard type.load(as: Any.Type.self) == Int.self else { return false }
    outValue.initializeMemory(as: Int.self, to: 2)
    return true
}, 2, 0)

@section("linker_sets") @used
private let decliningRecord: LinkerSetRecord.Literal = (0x6C73_6131, 0, { _, _, _, _ in false }, 3, 0)

@section("linker_sets") @used
private let otherKindRecord: LinkerSetRecord.Literal = (0x6C73_6132, 0, { outValue, type, _, _ in
    guard type.load(as: Any.Type.self) == Int.self else { return false }
    outValue.initializeMemory(as: Int.self, to: 100)
    return true
}, 100, 0)
#endif

@Suite("LinkerSet: enumeration")
struct LinkerSetEnumerationTests {
    @Test("Every record of a kind is found, and none of another kind")
    func everyRecordOfItsKind() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_6131))
        let expectedContexts: [UInt] = [0, 2, 3]

        let actual = sut.records

        #expect(actual.map(\.context).sorted() == expectedContexts)
        #expect(actual.allSatisfy { $0.kind.rawValue == 0x6C73_6131 })
    }

    @Test("Values hold what each record produces, leaving out a record that declines the type")
    func values() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_6131))
        let expected = [1, 2]

        let actual = sut.values

        #expect(actual.sorted() == expected)
    }

    @Test("Another kind's set holds only its own record")
    func otherKind() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6C73_6132))
        let expected = [100]

        let actual = sut.values

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
        let sut = LinkerSet<String>(kind: LinkerSetKind(rawValue: 0x6C73_6131))
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
        let expected = sut.records.map(\.context)

        let actual = sut.records.map(\.context)

        #expect(actual == expected)
        #expect(sut.values == sut.values)
    }

    @Test("A set holds exactly the section's records of its kind, in section order", .tags(.randomized))
    func matchesNaiveFilter() async {
        let kind = Gen.element(of: [0x6C73_6131, 0x6C73_6132, 0x6C73_6139] as [UInt32]).map { $0! }
        await propertyCheck(count: 50, input: kind) { kind in
            let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: kind))
            var expected: [UInt] = []
            for record in LinkerSetSection.records() where record.kind.rawValue == kind && record.accessor != nil {
                expected.append(record.context)
            }

            let actual = sut.records.map(\.context)

            #expect(actual == expected)
        }
    }
}
#endif
