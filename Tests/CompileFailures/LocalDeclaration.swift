// A local exists only while its scope runs.
import LinkerSets

func configure() {
    @LinkerSetEntry(kind: 0x6366_0006)
    let volume = 1
    _ = volume
}
