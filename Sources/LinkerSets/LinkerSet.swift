#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
/// Every record of one kind, across every image the program has loaded, and the values they
/// produce.
///
/// Records are declared at compile time as `@used` globals in the section LinkerSets owns. In a
/// Mach-O image that is `__DATA_CONST,__linker_sets`, each record a ``LinkerSetRecord/Literal``.
/// In an ELF image it is the note section `.note.linker_sets`, each record wrapped in a
/// ``LinkerSetRecord/Note``. In a WebAssembly module it is the data section `linker_sets`, and in
/// a PE image (Windows) the grouped section `.lnkset$M`, which the linker merges into `.lnkset`. A
/// linker set finds them at run time in every image the loader has mapped: the program, the
/// shared libraries it was linked with, and any loaded later with `dlopen`. On Apple platforms it
/// reads each image's section through the loader's list of images; on ELF platforms (Linux,
/// Android, FreeBSD) it reads each image's note segments through `dl_iterate_phdr`; on
/// WebAssembly (WASI), whose program is one statically linked module, it reads the section
/// between the `__start_linker_sets` and `__stop_linker_sets` symbols wasm-ld defines; on Windows
/// it reads each loaded module's `.lnkset` section through `K32EnumProcessModules` and the
/// module's PE section table, skipping the zero padding the linker may put between contributions:
///
/// ```swift
/// let routes = LinkerSet<Route>(kind: .routes).values
/// ```
///
/// Each read asks the loader again, so a read after a `dlopen` includes the new image's records.
/// Records come back image by image in the loader's order, and within an image in the order the
/// linker laid them out, so two reads with no load between them return the same records in the
/// same order.
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
/// record; on ELF, a note that isn't LinkerSets', or whose record size this version doesn't know,
/// is skipped.
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
