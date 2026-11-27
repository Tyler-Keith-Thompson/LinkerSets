import LinkerSets

// Records in a shared library the test program links at launch (SHARED_LIBRARIES in
// scripts/modules.py), so they sit in an image of their own rather than in the program's. The kind
// is "dyn1".

/// The library's records.
enum DynamicPlugins {
    /// The first record.
    @LinkerSetEntry(kind: 0x6479_6E31)
    static let first = 1

    /// The second record.
    @LinkerSetEntry(kind: 0x6479_6E31)
    static let second = 2
}
