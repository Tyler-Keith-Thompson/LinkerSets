// An initializer is none of the declarations a record describes.
import LinkerSets

struct Settings {
    @LinkerSetEntry(kind: 0x6366_0008)
    init() {}
}
