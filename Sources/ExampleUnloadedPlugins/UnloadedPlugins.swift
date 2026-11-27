import LinkerSets

// Records in a shared library the test opens and closes again and again with dlopen and dlclose
// while another thread reads (SHARED_LIBRARIES in scripts/modules.py), apart from
// ExampleLoadedPlugins, which its test keeps open. The kind is "dyn3".

/// The library's records.
enum UnloadedPlugins {
    /// The first record.
    @LinkerSetEntry(kind: 0x6479_6E33)
    static let first = 30

    /// The second record.
    @LinkerSetEntry(kind: 0x6479_6E33)
    static let second = 40
}
