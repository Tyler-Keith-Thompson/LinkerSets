// A requirement has no value of its own.
import LinkerSets

protocol Plugin {
    @LinkerSetEntry(kind: 0x6366_0007)
    static func load()
}
