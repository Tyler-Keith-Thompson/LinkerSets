// A static member of a generic type differs per specialization.
import LinkerSets

struct Box<T> {
    @LinkerSetEntry(kind: 0x6366_0003)
    static func make() {}
}
