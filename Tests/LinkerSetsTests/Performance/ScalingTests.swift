// How reading a set scales with the records it holds, over ExampleManyRecords' 300 and 3,000
// generated records. Speed-reliant, so release builds alone run it. Every read walks the same
// sections (all 3,300 records and the rest), so the two sizes differ only in the records they
// produce: the bound catches work that grows faster than the records do. Each time is the
// fastest of several reads, which a busy machine slows less than an average. Each test is
// self-contained.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
import ExampleManyRecords
import LinkerSets
import Testing

@Suite("Scaling: reading a set grows with its records", .timeLimit(.minutes(1)))
struct ScalingTests {
    @Test("Every generated record is found, in declaration order")
    func everyRecordIsFound() {
        let expectedFewer = Array(0..<300)
        let expectedMore = Array(0..<3_000)

        let actualFewer = LinkerSet<Int>(kind: ManyRecords.fewer).values
        let actualMore = LinkerSet<Int>(kind: ManyRecords.more).values

        #expect(actualFewer == expectedFewer)
        #expect(actualMore == expectedMore)
    }

    @Test("Reading 3,000 records costs at most about 10 times reading 300")
    func linearInRecords() {
        let clock = ContinuousClock()
        let rounds = 25
        // Linear is 10 times; the slack absorbs timer resolution and noise at these short times.
        let allowedRatio = 15.0
        var fewer = Duration.seconds(1_000)
        var more = Duration.seconds(1_000)
        for _ in 0..<rounds {
            fewer = min(fewer, clock.measure { _ = LinkerSet<Int>(kind: ManyRecords.fewer).values })
            more = min(more, clock.measure { _ = LinkerSet<Int>(kind: ManyRecords.more).values })
        }

        let actual = more / fewer

        #expect(actual <= allowedRatio, "300 records: \(fewer); 3,000 records: \(more)")
    }
}
#endif
