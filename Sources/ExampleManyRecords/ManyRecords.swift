import LinkerSets

// Records in bulk, for the tests of how reading scales: Generated/Records/ holds 300 records of
// one kind and 3,000 of another, split across ten files, which tools/many_records writes from
// records.txt.

/// The kinds of this module's generated records, and how many of each it holds.
public enum ManyRecords {
    /// The kind of the 300 records, `"man1"`, each an `Int`.
    public static let fewer = LinkerSetKind(rawValue: 0x6D61_6E31)
    /// The kind of the 3,000 records, `"man2"`, each an `Int`.
    public static let more = LinkerSetKind(rawValue: 0x6D61_6E32)
}
