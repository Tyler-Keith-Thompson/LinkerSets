#if objectFormat(Wasm)
// A record of kind 0, which holds no records, so the section exists in every module that links
// this file, and wasm-ld defines its __start_ and __stop_ symbols even when no client has
// declared a record.
@section("linker_sets") @used
private let emptySlot: LinkerSetRecord.Literal = (0, 0, { _, _, _, _ in false }, 0, 0)

// wasm-ld defines __start_<section> and __stop_<section> for a data section whose name is a C
// identifier: the linear-memory addresses of its first byte and of the byte after its last. They
// are declared as variables, whose addresses are memory addresses; a function's address in wasm
// is an index into the function table, not a place in memory. `@_extern(c)` is the Extern
// experimental feature (EXPERIMENTAL_FEATURES in scripts/modules.py). Only their addresses are
// taken; neither is read or written.
@_extern(c, "__start_linker_sets") nonisolated(unsafe) private var sectionStart: UInt8
@_extern(c, "__stop_linker_sets") nonisolated(unsafe) private var sectionStop: UInt8

extension LinkerSetSection {
    /// Every record in the module's section, in the order the linker laid them out.
    ///
    /// A WebAssembly program is one statically linked module, so the bounds cover every record it
    /// holds.
    static func records() -> [LinkerSetRecord] {
        let start = withUnsafePointer(to: &sectionStart) { UnsafeRawPointer($0) }
        let stop = withUnsafePointer(to: &sectionStop) { UnsafeRawPointer($0) }
        // A stop below the start would be a broken linker; read nothing rather than trap.
        return records(in: UnsafeRawBufferPointer(start: start, count: max(0, stop - start)))
    }
}
#endif
