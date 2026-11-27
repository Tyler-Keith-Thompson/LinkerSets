#if objectFormat(ELF)
// dl_iterate_phdr is documented in glibc and bionic (link.h). Swift's Glibc module
// doesn't export link.h, so it is declared here with `@_extern(c)` (the Extern experimental
// feature, EXPERIMENTAL_FEATURES in scripts/modules.py): an ordinary reference the linker
// resolves, not a lookup by name. The callback takes `dl_phdr_info` as a raw pointer, read at the
// offsets link.h documents, because a Swift struct can't cross a C function type.
@_extern(c, "dl_iterate_phdr")
private func dl_iterate_phdr(
    _ callback: @convention(c) (UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Int32,
    _ context: UnsafeMutableRawPointer?
) -> Int32

extension LinkerSetSection {
    /// Every record in every image the loader has mapped, image by image in the loader's order
    /// (the program, then its libraries, then each `dlopen`ed image as it was loaded), and within
    /// an image in the order the linker laid them out.
    ///
    /// Each image's records are the LinkerSets notes in its `PT_NOTE` segments; see
    /// ``LinkerSetRecord/Note``.
    static func records() -> [LinkerSetRecord] {
        var records: [LinkerSetRecord] = []
        withUnsafeMutablePointer(to: &records) { records in
            // The loader holds its lock while it calls back, so the callback only copies records
            // out; no accessor runs until it returns.
            _ = dl_iterate_phdr({ info, _, context in
                guard let info, let context else { return 0 }
                let records = context.assumingMemoryBound(to: [LinkerSetRecord].self)
                for segment in ProgramHeader.notes(of: UnsafeRawPointer(info)) {
                    records.pointee += LinkerSetSection.records(inNotes: segment)
                }
                return 0
            }, UnsafeMutableRawPointer(records))
        }
        return records
    }

    /// The records in a note segment's bytes: the descriptors of its LinkerSets notes whose size is
    /// a record's, in order. Other notes, and LinkerSets notes of another size (a layout this
    /// version doesn't know), are skipped; a note that runs past the segment ends the walk.
    ///
    /// - Parameter segment: The segment's bytes and its notes' alignment.
    /// - Complexity: O(*n*) in the segment's size.
    static func records(inNotes segment: NoteSegment) -> [LinkerSetRecord] {
        var records: [LinkerSetRecord] = []
        let bytes = segment.bytes
        var offset = 0
        while offset + 12 <= bytes.count {
            let remaining = UInt32(clamping: bytes.count - offset)
            let nameSize = bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            let descriptorSize = bytes.loadUnaligned(fromByteOffset: offset + 4, as: UInt32.self)
            let type = bytes.loadUnaligned(fromByteOffset: offset + 8, as: UInt32.self)
            // Sizes are checked against what's left before they become Ints: a corrupt header's
            // could otherwise overflow a 32-bit Int.
            guard nameSize <= remaining, descriptorSize <= remaining else { break }
            let nameStart = offset + 12
            let descriptorStart = segment.aligned(nameStart + Int(nameSize))
            guard descriptorStart + Int(descriptorSize) <= bytes.count else { break }
            let name = UnsafeRawBufferPointer(rebasing: bytes[nameStart ..< nameStart + Int(nameSize)])
            if type == noteType, name.elementsEqual(noteName), Int(descriptorSize) == MemoryLayout<LinkerSetRecord>.stride {
                records.append(bytes.loadUnaligned(fromByteOffset: descriptorStart, as: LinkerSetRecord.self))
            }
            offset = segment.aligned(descriptorStart + Int(descriptorSize))
        }
        return records
    }

    /// The name of a LinkerSets note, with its terminating zero.
    static let noteName = Array("LinkerSets".utf8) + [0]
    /// The type of a LinkerSets note that holds a record.
    static let noteType: UInt32 = 1
}

/// A `PT_NOTE` segment's bytes in a loaded image, and the alignment its notes are padded to.
struct NoteSegment {
    let bytes: UnsafeRawBufferPointer
    let alignment: Int

    /// `offset` rounded up to the notes' alignment.
    func aligned(_ offset: Int) -> Int {
        (offset + alignment - 1) / alignment * alignment
    }
}

/// The fields of an ELF program header that locate a segment, read from `dl_phdr_info`.
private enum ProgramHeader {
    private static let noteSegmentType: UInt32 = 4  // PT_NOTE

    /// The note segments of the image `info` (a `struct dl_phdr_info *`) describes.
    static func notes(of info: UnsafeRawPointer) -> [NoteSegment] {
        // struct dl_phdr_info { ElfW(Addr) dlpi_addr; const char *dlpi_name;
        //                       const ElfW(Phdr) *dlpi_phdr; ElfW(Half) dlpi_phnum; ... }
        let word = MemoryLayout<UInt>.size
        let base = info.load(as: UInt.self)
        guard let headers = info.load(fromByteOffset: 2 * word, as: UnsafeRawPointer?.self) else { return [] }
        let count = Int(info.load(fromByteOffset: 3 * word, as: UInt16.self))
        return (0 ..< count).compactMap { index in
            let header = headers + index * headerSize
            guard header.loadUnaligned(as: UInt32.self) == noteSegmentType else { return nil }
            let fields = fields(of: header)
            guard fields.size > 0, let start = UnsafeRawPointer(bitPattern: base &+ fields.address) else { return nil }
            return NoteSegment(bytes: UnsafeRawBufferPointer(start: start, count: fields.size), alignment: fields.alignment == 8 ? 8 : 4)
        }
    }

    #if _pointerBitWidth(_64)
    // Elf64_Phdr: p_type, p_flags (UInt32 each), then p_offset, p_vaddr, p_paddr, p_filesz,
    // p_memsz, p_align (UInt64 each).
    private static let headerSize = 56

    private static func fields(of header: UnsafeRawPointer) -> (address: UInt, size: Int, alignment: UInt) {
        (UInt(header.loadUnaligned(fromByteOffset: 16, as: UInt64.self)),
         Int(clamping: header.loadUnaligned(fromByteOffset: 40, as: UInt64.self)),
         UInt(header.loadUnaligned(fromByteOffset: 48, as: UInt64.self)))
    }
    #else
    // Elf32_Phdr: p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_flags, p_align (UInt32
    // each).
    private static let headerSize = 32

    private static func fields(of header: UnsafeRawPointer) -> (address: UInt, size: Int, alignment: UInt) {
        (UInt(header.loadUnaligned(fromByteOffset: 8, as: UInt32.self)),
         Int(clamping: header.loadUnaligned(fromByteOffset: 20, as: UInt32.self)),
         UInt(header.loadUnaligned(fromByteOffset: 28, as: UInt32.self)))
    }
    #endif
}
#endif
