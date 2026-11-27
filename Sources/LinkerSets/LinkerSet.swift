#if objectFormat(MachO) || objectFormat(ELF)
/// Every record of one kind, across every image the program has loaded, and the values they
/// produce.
///
/// Records are declared at compile time as `@used` globals in the section LinkerSets owns
/// (`@section("__DATA_CONST,__linker_sets")` in a Mach-O image, `@section("linker_sets")` in an
/// ELF one), each a ``LinkerSetRecord/Literal``. A linker set finds them at run time: on Apple
/// platforms through the loader's list of images, and on ELF platforms (Linux, Android, FreeBSD)
/// between the section's linker-defined `__start_linker_sets` and `__stop_linker_sets` symbols,
/// which bound the records of the statically linked program:
///
/// ```swift
/// let routes = LinkerSet<Route>(kind: .routes).values
/// ```
///
/// Records come back image by image in the loader's order, and within an image in the order the
/// linker laid them out, so two reads in one process return the same records in the same order.
/// A kind no record was declared with gives an empty set, as does kind 0, which marks an empty
/// slot.
///
/// Records survive dead stripping (`-dead_strip`, `--gc-sections`) in debug and release builds:
/// each is `@used`, and the section is retained. A record reaches the program only when the
/// linker links its module's object file, though. SwiftPM links every object of a target's
/// dependencies, and so does Bazel's `swift_library`, which is `alwayslink` by default. A build
/// that links a static archive's members only on demand drops a module that nothing references
/// by name. Link such a module whole (`-force_load` on Mach-O, `--whole-archive` on ELF).
///
/// Reading never traps. A record whose reserved fields aren't zero, written by a newer layout, is
/// skipped; a section whose size isn't a whole number of records is read up to its last whole
/// record.
public struct LinkerSet<Value>: Sendable {
    /// The kind of record this set holds.
    public let kind: LinkerSetKind

    /// The set of records of `kind`.
    ///
    /// - Parameter kind: The kind the records were declared with.
    public init(kind: LinkerSetKind) {
        self.kind = kind
    }

    /// Every record of this set's kind, skipping other kinds' records, empty slots and records of
    /// a layout this version doesn't know (``LinkerSetRecord/isSupportedVersion``).
    ///
    /// - Complexity: O(*n*) in the number of records of every kind in every loaded image.
    public var records: [LinkerSetRecord] {
        guard kind != .emptySlot else { return [] }
        return LinkerSetSection.records().filter { $0.kind == kind && $0.accessor != nil && $0.isSupportedVersion }
    }

    /// The value of each record that produces a `Value`, in the order of ``records``.
    ///
    /// A record whose accessor declines `Value` is left out.
    ///
    /// - Complexity: O(*n*) in the number of records of every kind in every loaded image.
    public var values: [Value] {
        records.compactMap { try? $0.value(as: Value.self) }
    }
}
#endif
