/// The section LinkerSets owns in each image, read through the object format's documented
/// mechanism. Each format's reader is an extension in a file of its own.
enum LinkerSetSection {
    /// The whole records in `bytes`, a section's contents, in order.
    ///
    /// Each record is loaded unaligned, so a section that starts off a record's alignment can't
    /// trap, and trailing bytes too few for a record are left out.
    ///
    /// - Complexity: O(*n*) in the number of records.
    static func records(in bytes: UnsafeRawBufferPointer) -> [LinkerSetRecord] {
        let stride = MemoryLayout<LinkerSetRecord>.stride
        return (0 ..< bytes.count / stride).map { index in
            bytes.loadUnaligned(fromByteOffset: index * stride, as: LinkerSetRecord.self)
        }
    }

    /// The records in `bytes`, a section the linker may have padded with zeros between the
    /// contributions of different object files, in order.
    ///
    /// Padding comes in multiples of a record's alignment, so the walk steps one alignment at a
    /// time over a zero kind and one record at a time over anything else. A record's kind is
    /// never 0 (the macros refuse it), so a zero kind is padding or an empty slot, and neither
    /// holds a record. Trailing bytes too few for a record are left out.
    ///
    /// - Complexity: O(*n*) in the section's size.
    static func records(skippingPadding bytes: UnsafeRawBufferPointer) -> [LinkerSetRecord] {
        let stride = MemoryLayout<LinkerSetRecord>.stride
        let alignment = MemoryLayout<LinkerSetRecord>.alignment
        var records: [LinkerSetRecord] = []
        var offset = 0
        while offset + stride <= bytes.count {
            if bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self) == 0 {
                offset += alignment
            } else {
                records.append(bytes.loadUnaligned(fromByteOffset: offset, as: LinkerSetRecord.self))
                offset += stride
            }
        }
        return records
    }
}
