// A generic function has no one concrete value to store.
import LinkerSets

@LinkerSetEntry(kind: 0x6366_0001)
func identity<T>(_ value: T) -> T { value }
