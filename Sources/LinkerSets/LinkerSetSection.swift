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
}
