// An instance property has no value without an instance.
import LinkerSets

struct Settings {
    @LinkerSetEntry(kind: 0x6366_0004)
    let volume = 1
}
