#if objectFormat(ELF)
// A record of kind 0, which holds no records, so the section exists in every image that links
// this file, and the linker defines its __start_ and __stop_ symbols even when no client has
// declared a record. `@used` marks it SHF_GNU_RETAIN, so `--gc-sections` keeps the section.
@section("linker_sets") @used
private let emptySlot: LinkerSetRecord.Literal = (0, 0, { _, _, _, _ in false }, 0, 0)

// The linker defines __start_<section> and __stop_<section> for a section whose name is a C
// identifier: the addresses of its first byte and of the byte after its last. Swift declares an
// external C symbol only as a function, so these are declared as functions and only their
// addresses are taken; they are never called. `@_extern(c)` (the Extern experimental feature,
// EXPERIMENTAL_FEATURES in scripts/modules.py) rather than `@_silgen_name`, whose address can
// only be taken as a `@convention(thin)` value, which crashes the Swift 6.4 compiler in Swift 6
// mode; a C header would take a C target in both build systems for two declarations.
@_extern(c, "__start_linker_sets") private func sectionStart()
@_extern(c, "__stop_linker_sets") private func sectionStop()

extension LinkerSetSection {
    /// Every record in the image's section, in the order the linker laid them out.
    ///
    /// The bounds cover the image this file is linked into: the whole program when it is linked
    /// statically, as Swift links its packages on Linux by default.
    static func records() -> [LinkerSetRecord] {
        let start = unsafeBitCast(sectionStart as @convention(c) () -> Void, to: UnsafeRawPointer.self)
        let stop = unsafeBitCast(sectionStop as @convention(c) () -> Void, to: UnsafeRawPointer.self)
        // A stop below the start would be a broken linker; read nothing rather than trap.
        return records(in: UnsafeRawBufferPointer(start: start, count: max(0, stop - start)))
    }
}
#endif
