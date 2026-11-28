// A plain extension doesn't say its type is generic, so the macro can't refuse a member there;
// the compiler refuses the record inside the expansion instead.
import LinkerSets

struct Box<T> {}

extension Box {
    @LinkerSetEntry(kind: 0x6366_0003)
    static func make() {}
}
