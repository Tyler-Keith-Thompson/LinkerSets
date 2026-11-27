// A var of a @MainActor type is isolated to the main actor, out of a record's accessor's reach.
import LinkerSets

@MainActor
enum Counters {
    @LinkerSetEntry(kind: 0x6366_000E)
    static var taps = 0
}
