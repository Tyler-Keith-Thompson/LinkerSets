// An instance method needs an instance to call.
import LinkerSets

struct Settings {
    @LinkerSetEntry(kind: 0x6366_0005)
    func reset() {}
}
