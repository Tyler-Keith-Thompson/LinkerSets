#if objectFormat(MachO)
import MachO

extension LinkerSetSection {
    /// The section's segment and name in a Mach-O image: `@section("__DATA_CONST,__linker_sets")`.
    static let segmentName = "__DATA_CONST"
    static let sectionName = "__linker_sets"

    /// Every record in every image the loader has mapped, image by image in the loader's order,
    /// and within an image in the order the linker laid them out.
    static func records() -> [LinkerSetRecord] {
        // The loader's image list and getsectiondata are the documented way to find a section in
        // each loaded image, with no symbol lookup by name and no reading of Swift's metadata.
        (0 ..< _dyld_image_count()).flatMap { index -> [LinkerSetRecord] in
            guard let header = _dyld_get_image_header(index) else { return [] }
            return records(in: header)
        }
    }

    private static func records(in header: UnsafePointer<mach_header>) -> [LinkerSetRecord] {
        var size: UInt = 0
        #if _pointerBitWidth(_64)
        let image = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
        #else
        let image = header
        #endif
        guard let start = getsectiondata(image, segmentName, sectionName, &size) else { return [] }
        let count = Int(size) / MemoryLayout<LinkerSetRecord>.stride
        return UnsafeRawPointer(start).withMemoryRebound(to: LinkerSetRecord.self, capacity: count) { first in
            Array(UnsafeBufferPointer(start: first, count: count))
        }
    }
}
#endif
