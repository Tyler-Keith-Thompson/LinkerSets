import LinkerSets

// Records in a shared library no program links: the test opens it with `dlopen` (SHARED_LIBRARIES
// in scripts/modules.py), so they exist in the process only once it is loaded. The kind is "dyn2".

/// The library's records.
enum LoadedPlugins {
    /// The first record.
    @LinkerSetEntry(kind: 0x6479_6E32)
    static let first = 10

    /// The second record.
    @LinkerSetEntry(kind: 0x6479_6E32)
    static let second = 20
}
