// A module that writes records without depending on LinkerSets (ExampleSessions, through
// ExampleDiscovery's own @Discoverable(kind:) and #discoverableRecord). Each test is
// self-contained.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
import ExampleSessions
import LinkerSetsRuntime
import Testing

@Suite("A module that writes records on LinkerSetsRuntime alone")
struct RuntimeOnlyWriterTests {
    @Test("Records a module wrote with a client's own record macro are found, members and a global alike")
    func recordsWrittenWithoutLinkerSets() {
        let sut = LinkerSet<String>(kind: SessionEvents.kind)
        let expected = ["session ended", "session started", "session timed out"]

        let actual = sut.values.sorted()

        #expect(actual == expected)
    }
}
#endif
