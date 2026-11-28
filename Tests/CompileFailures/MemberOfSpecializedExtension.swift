// An extension that names generic arguments shows its type is generic, so the macro refuses it.
import LinkerSets

struct Box<T> {}

extension Box<Int> {
    @LinkerSetEntry(kind: 0x6366_0003)
    static func make() {}
}
