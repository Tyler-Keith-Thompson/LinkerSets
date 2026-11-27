// A property marked @MainActor can't be read by a record's nonisolated accessor.
import LinkerSets

enum Labels {
    @MainActor @LinkerSetEntry(kind: 0x6366_000D)
    static let back = "Back"
}
