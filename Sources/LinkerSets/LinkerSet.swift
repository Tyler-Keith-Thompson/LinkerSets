#if canImport(MachO)
/// Every record of one kind, across every image the program has loaded, and the values they
/// produce.
///
/// Records are declared at compile time as `@used` globals in the section LinkerSets owns
/// (`@section("__DATA_CONST,__linker_sets")` in a Mach-O image), each a ``LinkerSetRecord/Literal``.
/// A linker set finds them at run time through the loader's list of images:
///
/// ```swift
/// let routes = LinkerSet<Route>(kind: .routes).values
/// ```
///
/// Records come back image by image in the loader's order, and within an image in the order the
/// linker laid them out, so two reads in one process return the same records in the same order.
public struct LinkerSet<Value>: Sendable {
    /// The kind of record this set holds.
    public let kind: LinkerSetKind

    /// The set of records of `kind`.
    ///
    /// - Parameter kind: The kind the records were declared with.
    public init(kind: LinkerSetKind) {
        self.kind = kind
    }

    /// Every record of this set's kind, skipping other kinds' records and empty slots.
    ///
    /// - Complexity: O(*n*) in the number of records of every kind in every loaded image.
    public var records: [LinkerSetRecord] {
        LinkerSetSection.records().filter { $0.kind == kind && $0.accessor != nil }
    }

    /// The value of each record that produces a `Value`, in the order of ``records``.
    ///
    /// A record whose accessor declines `Value` is left out.
    ///
    /// - Complexity: O(*n*) in the number of records of every kind in every loaded image.
    public var values: [Value] {
        records.compactMap { $0.value(as: Value.self) }
    }
}
#endif
